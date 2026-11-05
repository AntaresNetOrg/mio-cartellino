/// Hours/minutes helpers. Port of `cartellino/ore_helpers.py`.
library;

import 'cartellino.dart';

final _oreRe = RegExp(r'\d\d\.');
final _minutiRe = RegExp(r'\.\d\d');

/// Extracts (hours, minutes) from the `HH.MM` pattern of a voce base
/// (`"OE-DIU 02.30"` -> `(2, 30)`). Same regexes as the desktop app.
/// Throws [FormatException] when the pattern is missing.
(int, int) estraiOreMinuti(String voce) {
  final ore = _oreRe.firstMatch(voce)?.group(0);
  final minuti = _minutiRe.firstMatch(voce)?.group(0);
  if (ore == null || minuti == null) {
    throw FormatException('Ore/minuti (HH.MM) non trovati', voce);
  }
  return (int.parse(ore.substring(0, ore.length - 1)), int.parse(minuti.substring(1)));
}

/// Total minutes of [voce], or null if it has no `HH.MM` pattern.
int? tryMinuti(String voce) {
  try {
    final (h, m) = estraiOreMinuti(voce);
    return h * 60 + m;
  } on FormatException {
    return null;
  }
}

/// Codes whose value is subtracted in balances (desktop issue #8:
/// base +00:07, SCN 00:26 -> -00:19).
const subtractiveCodes = {'SCN'};

/// Signed balance in minutes of [entries] restricted to [codici].
/// Throws [FormatException] if a matching voce has no `HH.MM` value
/// (same behaviour as the desktop app).
int saldoMinuti(Iterable<CartellinoEntry> entries, Iterable<String> codici) {
  final wanted = codici.toSet();
  var total = 0;
  for (final e in entries) {
    if (!wanted.contains(e.codice)) continue;
    final (h, m) = estraiOreMinuti(e.voce);
    final value = h * 60 + m;
    total += subtractiveCodes.contains(e.codice) ? -value : value;
  }
  return total;
}

/// Entries of [entries] falling in the same month/year as [ref].
Iterable<CartellinoEntry> inMonth(Iterable<CartellinoEntry> entries, DateTime ref) =>
    entries.where((e) => e.date.year == ref.year && e.date.month == ref.month);
