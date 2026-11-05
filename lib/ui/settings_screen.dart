import 'package:flutter/material.dart';

import '../domain/clock.dart';
import '../domain/excluded_date.dart';
import '../domain/settings.dart';
import '../services.dart';

/// Impostazioni / onboarding: year, min date for used riposi, excluded dates.
///
/// TODO: editing of dashboard exception/balance codes (desktop "Impostazioni").
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings? _settings;
  bool _firstRun = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await widget.services.settings.load();
    final firstRun = await widget.services.settings.isFirstRun();
    if (mounted) {
      setState(() {
        _settings = settings;
        _firstRun = firstRun;
      });
    }
  }

  Future<void> _update(AppSettings settings) async {
    await widget.services.settings.save(settings);
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _firstRun = false;
    });
    widget.services.notifyChanged();
  }

  Future<void> _pickMinDate(AppSettings s) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: s.minDate,
      firstDate: DateTime(s.year, 1, 1),
      lastDate: DateTime(s.year, 12, 31),
      helpText: 'Conta i riposi fruiti (SRC) dopo il',
    );
    if (picked != null) {
      await _update(s.copyWith(minDateMonth: picked.month, minDateDay: picked.day));
    }
  }

  Future<void> _addExcludedDate(AppSettings s) async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: now.year == s.year ? now : DateTime(s.year, 1, 1),
      firstDate: DateTime(s.year, 1, 1),
      lastDate: DateTime(s.year, 12, 31),
      helpText: 'Data da escludere dalle ore eccedenti',
    );
    if (day == null || !mounted) return;
    final partial = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(formatDate(day)),
        content: const Text('Escludere tutta la giornata o sottrarre solo alcune ore?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Tutta')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sottrai ore')),
        ],
      ),
    );
    if (partial == null || !mounted) return;
    int? subtract;
    if (partial) {
      final t = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 1, minute: 0),
        helpText: 'Ore da sottrarre (HH:MM)',
        initialEntryMode: TimePickerEntryMode.input,
      );
      if (t == null) return;
      subtract = hm(t.hour, t.minute);
    }
    final added = ExcludedDate(day, subtractMinutes: subtract);
    await _update(s.copyWith(
      excludedDates: [...s.excludedDates.where((e) => dayOf(e.date) != dayOf(day)), added]
        ..sort((a, b) => a.date.compareTo(b.date)),
    ));
  }

  /// Paste the content of the desktop app's date_escluse.txt.
  Future<void> _importExcludedDates(AppSettings s) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importa date escluse'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: '16-01-2025\n20-01-2025 03:30',
            helperText: 'Incolla il contenuto di date_escluse.txt',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Importa'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || !mounted) return;
    try {
      final parsed = ExcludedDate.parseFile(text);
      await _update(s.copyWith(excludedDates: parsed..sort((a, b) => a.date.compareTo(b.date))));
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Riga non valida: "${e.source}" (${e.message})')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (_firstRun)
                  const Card(
                    margin: EdgeInsets.all(16),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Benvenuto! Controlla anno e data minima dei riposi, '
                        'poi scarica il cartellino dalla scheda Riepilogo.',
                      ),
                    ),
                  ),
                ListTile(
                  title: const Text('Anno'),
                  trailing: DropdownButton<int>(
                    value: s.year,
                    items: [
                      for (final y in {DateTime.now().year - 1, DateTime.now().year, s.year})
                        DropdownMenuItem(value: y, child: Text('$y')),
                    ],
                    onChanged: (y) {
                      if (y != null) _update(s.copyWith(year: y));
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Riposi fruiti contati dopo il'),
                  subtitle: Text(formatDate(s.minDate)),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: () => _pickMinDate(s),
                ),
                const Divider(),
                ListTile(
                  title: const Text('Date escluse dalle ore eccedenti'),
                  subtitle: const Text('Come date_escluse.txt dell\'app desktop'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Importa da testo',
                        icon: const Icon(Icons.content_paste),
                        onPressed: () => _importExcludedDates(s),
                      ),
                      IconButton(
                        tooltip: 'Aggiungi',
                        icon: const Icon(Icons.add),
                        onPressed: () => _addExcludedDate(s),
                      ),
                    ],
                  ),
                ),
                for (final e in s.excludedDates)
                  ListTile(
                    dense: true,
                    title: Text(formatDate(e.date)),
                    subtitle: Text(e.isFullDay
                        ? 'Giornata intera'
                        : 'Sottrai ${formatHm(e.subtractMinutes!)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _update(s.copyWith(
                        excludedDates: s.excludedDates.where((x) => x != e).toList(),
                      )),
                    ),
                  ),
              ],
            ),
    );
  }
}
