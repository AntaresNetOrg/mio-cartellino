/// Helpers for times of day expressed as minutes since midnight.
///
/// The whole domain layer works with plain `int` minutes: it keeps the
/// arithmetic trivial and the tests readable (`hm(7, 50)` instead of
/// `DateTime`/`Duration` juggling).
library;

/// Minutes since midnight for [hours]:[minutes].
int hm(int hours, int minutes) => hours * 60 + minutes;

/// Formats [minutes] as `HH:MM`; negative values get a leading `-`.
String formatHm(int minutes) {
  final sign = minutes < 0 ? '-' : '';
  final abs = minutes.abs();
  final h = (abs ~/ 60).toString().padLeft(2, '0');
  final m = (abs % 60).toString().padLeft(2, '0');
  return '$sign$h:$m';
}

/// Like [formatHm] but always signed (`+00:42`, `-00:19`, `00:00`).
String formatSignedHm(int minutes) =>
    minutes > 0 ? '+${formatHm(minutes)}' : formatHm(minutes);

/// Parses `H:MM`, `HH:MM` or `HH.MM` into minutes since midnight.
/// Returns null on malformed input or out-of-range values.
int? parseHm(String text) {
  final match = RegExp(r'^(\d{1,2})[:.](\d{2})$').firstMatch(text.trim());
  if (match == null) return null;
  final h = int.parse(match.group(1)!);
  final m = int.parse(match.group(2)!);
  if (h > 23 || m > 59) return null;
  return hm(h, m);
}

/// Minutes since midnight of [time].
int minutesOfDay(DateTime time) => hm(time.hour, time.minute);

/// `dd/MM/yyyy`.
String formatDate(DateTime d) =>
    '${_two(d.day)}/${_two(d.month)}/${d.year.toString().padLeft(4, '0')}';

/// `dd-MM-yyyy`, the format used by the desktop app's text files
/// (`date_escluse.txt`, `riposi_usati.txt`).
String formatDateDash(DateTime d) =>
    '${_two(d.day)}-${_two(d.month)}-${d.year.toString().padLeft(4, '0')}';

/// Midnight of the same calendar day (drops the time part).
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

String _two(int v) => v.toString().padLeft(2, '0');
