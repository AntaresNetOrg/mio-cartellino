/// Dates excluded (fully or partially) from the OE-DIU computation.
///
/// Same text format as the desktop app's `date_escluse.txt`, so the user can
/// paste that file's content into the mobile app:
///
///     16-01-2025          -> whole day excluded
///     20-01-2025 03:30    -> subtract 03:30 from that day's ore eccedenti
library;

import 'clock.dart';

class ExcludedDate {
  const ExcludedDate(this.date, {this.subtractMinutes});

  /// Calendar day (time part ignored).
  final DateTime date;

  /// Minutes to subtract; null means the whole day is excluded.
  final int? subtractMinutes;

  bool get isFullDay => subtractMinutes == null;

  static final _re = RegExp(r'^(\d{2})-(\d{2})-(\d{4})(?:\s+(\d{2}):(\d{2}))?$');

  /// Parses one line; throws [FormatException] on malformed input.
  factory ExcludedDate.parse(String line) {
    final m = _re.firstMatch(line.trim());
    if (m == null) throw FormatException('Formato atteso DD-MM-YYYY [HH:MM]', line);
    final day = int.parse(m.group(1)!);
    final month = int.parse(m.group(2)!);
    final year = int.parse(m.group(3)!);
    final date = DateTime(year, month, day);
    if (date.day != day || date.month != month) {
      throw FormatException('Data non valida', line);
    }
    final subtract = m.group(4) == null
        ? null
        : int.parse(m.group(4)!) * 60 + int.parse(m.group(5)!);
    return ExcludedDate(date, subtractMinutes: subtract);
  }

  /// Parses a whole `date_escluse.txt`, skipping blank lines and `#` comments.
  static List<ExcludedDate> parseFile(String content) => [
        for (final line in content.split('\n'))
          if (line.trim().isNotEmpty && !line.trim().startsWith('#'))
            ExcludedDate.parse(line),
      ];

  String format() => isFullDay
      ? formatDateDash(date)
      : '${formatDateDash(date)} ${formatHm(subtractMinutes!)}';

  @override
  bool operator ==(Object other) =>
      other is ExcludedDate &&
      dayOf(other.date) == dayOf(date) &&
      other.subtractMinutes == subtractMinutes;

  @override
  int get hashCode => Object.hash(dayOf(date), subtractMinutes);
}
