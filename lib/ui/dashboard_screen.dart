import 'package:flutter/material.dart';

import '../domain/cartellino.dart';
import '../domain/clock.dart';
import '../domain/dashboard.dart';
import '../domain/demo_data.dart';
import '../domain/riposi.dart';
import '../domain/settings.dart';
import '../data/stores.dart';
import '../services.dart';
import '../theme/unisa_theme.dart';
import 'update_screen.dart';

class _DashboardData {
  const _DashboardData(this.settings, this.summary, {this.isDemo = false});
  final AppSettings settings;
  final bool isDemo;

  /// Null when no cartellino has been downloaded yet for settings.year.
  final DashboardSummary? summary;
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    widget.services.revision.addListener(_reload);
  }

  @override
  void dispose() {
    widget.services.revision.removeListener(_reload);
    super.dispose();
  }

  void _reload() => setState(() {
        _future = _load();
      });

  Future<_DashboardData> _load() async {
    final settings = await widget.services.settings.load();
    final stored = await widget.services.cartellino.load(settings.year);
    if (stored == null) return _DashboardData(settings, null);
    final entries = explodeRows(stored.rows, settings.year);
    return _DashboardData(
      settings,
      DashboardSummary.compute(
        entries: entries,
        settings: settings,
        now: DateTime.now(),
        lastUpdate: stored.fetchedAt,
      ),
      isDemo: stored.isDemo,
    );
  }

  /// Only offered when no cartellino is stored, so it can't replace real data. A real
  /// download overwrites the demo.
  Future<void> _startDemo(int year) async {
    final now = DateTime.now();
    await widget.services.cartellino.save(
      StoredCartellino(year: year, fetchedAt: now, rows: demoRows(now), isDemo: true),
    );
    widget.services.notifyChanged();
  }

  Future<void> _stopDemo(int year) async {
    await widget.services.cartellino.delete(year);
    widget.services.notifyChanged();
  }

  Future<void> _openUpdate(int year) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => UpdateScreen(services: widget.services, year: year)),
    );
    if (updated == true) widget.services.notifyChanged();
  }

  Widget _body(AsyncSnapshot<_DashboardData> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return _Message('Errore nella lettura del cartellino:\n${snapshot.error}');
    }
    final data = snapshot.requireData;
    final summary = data.summary;
    if (summary == null) {
      return _Empty(
        year: data.settings.year,
        onUpdate: () => _openUpdate(data.settings.year),
        onDemo: () => _startDemo(data.settings.year),
      );
    }
    final view = RefreshIndicator(
      onRefresh: () async => _reload(),
      child: _SummaryView(summary: summary, settings: data.settings),
    );
    if (!data.isDemo) return view;
    return Column(
      children: [
        MaterialBanner(
          content: const Text('Dati dimostrativi: non sono dati reali.'),
          leading: const Icon(Icons.science_outlined),
          actions: [
            TextButton(
              onPressed: () => _stopDemo(data.settings.year),
              child: const Text('Esci dalla demo'),
            ),
          ],
        ),
        Expanded(child: view),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Mio Cartellino'),
            actions: [
              if (data != null)
                IconButton(
                  tooltip: 'Aggiorna cartellino',
                  icon: const Icon(Icons.sync),
                  onPressed: () => _openUpdate(data.settings.year),
                ),
            ],
          ),
          body: _body(snapshot),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.year, required this.onUpdate, required this.onDemo});
  final int year;
  final VoidCallback onUpdate;
  final VoidCallback onDemo;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Nessun cartellino scaricato per il $year.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onUpdate,
                icon: const Icon(Icons.sync),
                label: const Text('Scarica cartellino'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onDemo,
                child: const Text('Prova con dati dimostrativi'),
              ),
            ],
          ),
        ),
      );
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(text)));
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({required this.summary, required this.settings});
  final DashboardSummary summary;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _section(context, 'saldo', 'Saldo ore del mese (${settings.balanceCodes.join(', ')})',
            summary.saldoMeseMinuti == null ? null : _saldo(context, summary.saldoMeseMinuti!)),
        _section(context, 'eccezioni', 'Eccezioni del mese (${settings.exceptionCodes.join(', ')})',
            summary.eccezioni == null ? null : _eccezioni(summary.eccezioni!)),
        _section(context, 'riposi', 'Riposi compensativi',
            summary.riposi == null ? null : _riposi(summary.riposi!)),
        _section(context, 'ferie', 'Ferie e permessi',
            summary.ferie == null ? null : _ferie(summary.ferie!)),
        if (summary.lastUpdate != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Ultimo aggiornamento: ${formatDate(summary.lastUpdate!)} '
              '${formatHm(minutesOfDay(summary.lastUpdate!))}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _section(BuildContext context, String key, String title, Widget? body) {
    final error = summary.errors[key];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (error != null)
              Text('Errore: $error', style: const TextStyle(color: UnisaColors.negative))
            else if (body != null)
              body,
          ],
        ),
      ),
    );
  }

  Widget _saldo(BuildContext context, int minuti) {
    final color = minuti > 0
        ? UnisaColors.positive
        : minuti < 0
            ? UnisaColors.negative
            : UnisaColors.neutral;
    return Text(
      formatSignedHm(minuti),
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color),
    );
  }

  Widget _eccezioni(List<Eccezione> list) {
    if (list.isEmpty) return const Text('Nessuna');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in list)
          Text('${formatDate(e.date)}  ${e.codice}  '
              '${e.minuti == null ? '--:--' : formatHm(e.minuti!)}'),
      ],
    );
  }

  Widget _riposi(List<RiposoCompensativo> list) {
    String label(RiposoCompensativo r) => switch (statoRiposo(r)) {
          StatoRiposo.usato => 'usato il ${r.dataUso}',
          StatoRiposo.completoConfermato => 'completo e confermato',
          StatoRiposo.completoNonConfermato => 'completo, non confermato',
          StatoRiposo.daCompletare => 'mancano ${formatHm(r.minutiMancanti)}',
        };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final r in list) Text('Riposo ${r.id}: ${label(r)}')],
    );
  }

  Widget _ferie(FerieCounts f) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ferie anno corrente: ${f.ferieAnnoCorrente}'),
          Text('Ferie anni precedenti: ${f.ferieAnniPrecedenti}'),
          Text('Festività soppresse: ${f.festivitaSoppresse}'),
          Text('Permessi gravi motivi familiari: ${f.permessiGraviMotivi}'),
        ],
      );
}
