import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/cartellino.dart';
import '../domain/clock.dart';
import '../domain/exit_time.dart';
import '../domain/ore.dart';
import '../services.dart';
import '../theme/unisa_theme.dart';

enum _AdjustMode { none, useCredit, recoverDebt }

/// "Uscita prevista": manual punches (the portal shows today's punches only
/// with a delay), optional explicit credit use / debt recovery.
class ExitTimeScreen extends StatefulWidget {
  const ExitTimeScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<ExitTimeScreen> createState() => _ExitTimeScreenState();
}

class _ExitTimeScreenState extends State<ExitTimeScreen> {
  List<int> _punches = [];
  _AdjustMode _mode = _AdjustMode.none;
  int _adjustMinutes = 0;

  /// Current month balance from the cached cartellino, if available.
  int? _balance;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _loadPunches();
    _loadBalance();
    widget.services.revision.addListener(_loadBalance);
    // Keeps the provisional result ("se rientri adesso") up to date.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _punches.length.isEven && _punches.isNotEmpty) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    widget.services.revision.removeListener(_loadBalance);
    super.dispose();
  }

  Future<void> _loadPunches() async {
    final punches = await widget.services.punches.load(DateTime.now());
    if (mounted) setState(() => _punches = punches);
  }

  Future<void> _loadBalance() async {
    int? balance;
    try {
      final settings = await widget.services.settings.load();
      final stored = await widget.services.cartellino.load(settings.year);
      if (stored != null) {
        final entries = explodeRows(stored.rows, settings.year);
        balance = saldoMinuti(inMonth(entries, DateTime.now()), settings.balanceCodes);
      }
    } catch (_) {
      balance = null; // the balance is only a hint here
    }
    if (mounted) setState(() => _balance = balance);
  }

  Future<void> _setPunches(List<int> punches) async {
    setState(() => _punches = punches);
    await widget.services.punches.save(DateTime.now(), punches);
  }

  Future<void> _addPunch(int minutes) async {
    if (_punches.contains(minutes)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Timbratura delle ${formatHm(minutes)} già presente')),
      );
      return;
    }
    await _setPunches([..._punches, minutes]..sort());
  }

  Future<void> _pickPunch() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null && mounted) await _addPunch(hm(picked.hour, picked.minute));
  }

  @override
  Widget build(BuildContext context) {
    final now = minutesOfDay(DateTime.now());
    ExitTimeResult? result;
    String? error;
    if (_punches.isNotEmpty) {
      try {
        result = computeExitTime(
          punches: _punches,
          creditUsed: _mode == _AdjustMode.useCredit ? _adjustMinutes : 0,
          debtRecovered: _mode == _AdjustMode.recoverDebt ? _adjustMinutes : 0,
          availableCredit: _balance,
          now: now,
        );
      } on InvalidPunchesException catch (e) {
        error = e.message;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Uscita prevista'),
        actions: [
          if (_punches.isNotEmpty)
            IconButton(
              tooltip: 'Azzera la giornata',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _setPunches([]),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ResultCard(result: result, error: error, balance: _balance),
          const SizedBox(height: 16),
          Text('Timbrature di oggi', style: Theme.of(context).textTheme.titleMedium),
          for (var i = 0; i < _punches.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text(i.isEven ? 'E' : 'U')),
              title: Text(formatHm(_punches[i])),
              subtitle: Text(i.isEven ? 'Entrata' : 'Uscita'),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => _setPunches([..._punches]..removeAt(i)),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _addPunch(now),
                icon: const Icon(Icons.touch_app),
                label: Text(_punches.length.isEven ? 'Entrata adesso' : 'Uscita adesso'),
              ),
              OutlinedButton.icon(
                onPressed: _pickPunch,
                icon: const Icon(Icons.edit_calendar),
                label: const Text('Altro orario'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Recupero', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<_AdjustMode>(
            segments: const [
              ButtonSegment(value: _AdjustMode.none, label: Text('Nessuno')),
              ButtonSegment(value: _AdjustMode.useCredit, label: Text('Uso credito')),
              ButtonSegment(value: _AdjustMode.recoverDebt, label: Text('Recupero debito')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          if (_mode != _AdjustMode.none) ...[
            Slider(
              value: _adjustMinutes.toDouble(),
              max: 120,
              divisions: 120,
              label: '$_adjustMinutes\'',
              onChanged: (v) => setState(() => _adjustMinutes = v.round()),
            ),
            Text(_mode == _AdjustMode.useCredit
                ? 'Esci $_adjustMinutes\' prima usando il credito'
                : 'Esci $_adjustMinutes\' dopo per recuperare il debito'),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.error, required this.balance});

  final ExitTimeResult? result;
  final String? error;
  final int? balance;

  String _warning(ExitTimeWarning w) => switch (w) {
        ExitTimeWarning.creditOverTolerance => 'Oltre 29\' di credito serve un permesso',
        ExitTimeWarning.debtOverTolerance => 'Oltre 29\' di recupero serve un permesso',
        ExitTimeWarning.creditExceedsBalance =>
          'Credito usato superiore al saldo del mese (${formatSignedHm(balance ?? 0)})',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = result;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (error != null)
              Text(error!, style: const TextStyle(color: UnisaColors.negative))
            else if (r == null)
              const Text('Inserisci la timbratura di entrata.')
            else ...[
              Text(r.provisional ? 'Uscita prevista se rientri adesso' : 'Uscita prevista',
                  style: theme.textTheme.titleMedium),
              Text(formatHm(r.exitAt),
                  style: theme.textTheme.displayMedium?.copyWith(color: UnisaColors.primary)),
              Text('Conteggio dalle ${formatHm(r.countedStart)}'
                  '${r.absenceMinutes > 0 ? ' · assenze +${formatHm(r.absenceMinutes)}' : ''}'),
              for (final w in r.warnings)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: UnisaColors.warning),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_warning(w))),
                    ],
                  ),
                ),
            ],
            if (balance != null) ...[
              const Divider(height: 24),
              Text('Saldo del mese: ${formatSignedHm(balance!)}', style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
