/// Local persistence: small JSON files in the app documents directory.
///
/// No credentials are ever stored: authentication is SPID/CIE level 2 inside
/// the WebView only (see CLAUDE.md § "Authentication").
library;

import 'dart:convert';
import 'dart:io';

import '../domain/cartellino.dart';
import '../domain/clock.dart';
import '../domain/settings.dart';

class JsonStore {
  JsonStore(this.directory);
  final Directory directory;

  File _file(String name) => File('${directory.path}/$name');

  Future<Map<String, dynamic>?> read(String name) async {
    final file = _file(name);
    if (!await file.exists()) return null;
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  /// Atomic write (temp file + rename).
  Future<void> write(String name, Map<String, dynamic> data) async {
    final file = _file(name);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(file.path);
  }
}

class SettingsStore {
  SettingsStore(this._store);
  final JsonStore _store;
  static const _file = 'settings.json';

  /// True until settings are saved once, which [HomeShell] does on the first launch.
  Future<bool> isFirstRun() async => await _store.read(_file) == null;

  Future<AppSettings> load() async {
    final json = await _store.read(_file);
    final now = DateTime.now();
    return json == null ? AppSettings.defaults(now) : AppSettings.fromJson(json, year: now.year);
  }

  Future<void> save(AppSettings settings) => _store.write(_file, settings.toJson());
}

class StoredCartellino {
  const StoredCartellino({required this.year, required this.fetchedAt, required this.rows});
  final int year;
  final DateTime fetchedAt;
  final List<CartellinoRow> rows;
}

/// Cache of the downloaded cartellino, one file per year.
class CartellinoRepository {
  CartellinoRepository(this._store);
  final JsonStore _store;

  String _file(int year) => 'cartellino_$year.json';

  Future<StoredCartellino?> load(int year) async {
    final json = await _store.read(_file(year));
    if (json == null) return null;
    return StoredCartellino(
      year: json['year'] as int,
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      rows: [
        for (final r in json['rows'] as List<dynamic>)
          CartellinoRow.fromJson(r as Map<String, dynamic>),
      ],
    );
  }

  Future<void> save(StoredCartellino c) => _store.write(_file(c.year), {
        'year': c.year,
        'fetchedAt': c.fetchedAt.toIso8601String(),
        'rows': [for (final r in c.rows) r.toJson()],
      });
}

/// Today's punches for the exit-time screen, so they survive app restarts.
/// Punches from a previous day are discarded on load.
class TodayPunchesStore {
  TodayPunchesStore(this._store);
  final JsonStore _store;
  static const _file = 'today_punches.json';

  Future<List<int>> load(DateTime today) async {
    final json = await _store.read(_file);
    if (json == null || json['date'] != formatDateDash(today)) return [];
    return (json['punches'] as List<dynamic>).cast<int>();
  }

  Future<void> save(DateTime today, List<int> punches) =>
      _store.write(_file, {'date': formatDateDash(today), 'punches': punches});
}
