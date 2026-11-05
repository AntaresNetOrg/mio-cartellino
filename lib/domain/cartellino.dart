/// Raw cartellino rows scraped from presenze.unisa.it and their "exploded"
/// form (one entry per "Voce Base").
///
/// Port of `cartellino/cartellino.py` (`Cartellino._from_raw`,
/// `get_date_from_string`, `extract_codice`) from the desktop app.
library;

/// One row of the portal table `#1011` (columns "Stato", "Data", "Voci Base").
///
/// Unlike the desktop app, which joins multiple voci with a NBSP-&-&-NBSP
/// separator and splits them again, the mobile scraper returns them already
/// split (see `assets/js/extract_cartellino.js`).
class CartellinoRow {
  const CartellinoRow({
    required this.stato,
    required this.data,
    required this.vociBase,
  });

  final String stato;

  /// Raw date text as shown by the portal, e.g. `lun 6 gen`.
  final String data;
  final List<String> vociBase;

  factory CartellinoRow.fromJson(Map<String, dynamic> json) => CartellinoRow(
        stato: json['stato'] as String,
        data: json['data'] as String,
        vociBase: (json['vociBase'] as List<dynamic>).cast<String>(),
      );

  Map<String, dynamic> toJson() =>
      {'stato': stato, 'data': data, 'vociBase': vociBase};
}

/// One "Voce Base" of a row, with its parsed date and code.
class CartellinoEntry {
  const CartellinoEntry({
    required this.stato,
    required this.data,
    required this.date,
    required this.voce,
    required this.codice,
  });

  final String stato;
  final String data;
  final DateTime date;
  final String voce;

  /// Code extracted from [voce] (`OE-DIU`, `SCN`, …) or `-` if none.
  final String codice;
}

const _monthMap = {
  'gen': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'mag': 5, 'giu': 6,
  'lug': 7, 'ago': 8, 'set': 9, 'ott': 10, 'nov': 11, 'dic': 12,
};

final _dateRe = RegExp(r'[a-z]{3}\s(\d\d?)\s([a-z]{3})', caseSensitive: false);
final _codiceRe = RegExp(r'[A-Z]+-?[A-Z][A-Z]+');

/// Parses the portal's date text (`lun 6 gen`) for [year].
/// Throws [FormatException] on unparsable or impossible dates.
DateTime parseCartellinoDate(String text, int year) {
  final match = _dateRe.firstMatch(text);
  if (match == null) throw FormatException('Data non riconosciuta', text);
  final day = int.parse(match.group(1)!);
  final month = _monthMap[match.group(2)!.toLowerCase()];
  if (month == null) throw FormatException('Mese non riconosciuto', text);
  final date = DateTime(year, month, day);
  // DateTime silently overflows (30 feb -> 2 mar): reject like Python does.
  if (date.month != month || date.day != day) {
    throw FormatException('Data non valida: $day/$month/$year', text);
  }
  return date;
}

/// Extracts the code from a voce base; `-` when none is found.
String extractCodice(String voce) =>
    _codiceRe.firstMatch(voce)?.group(0)?.trim() ?? '-';

/// One [CartellinoEntry] per voce base, preserving the portal's row order.
/// Rows without voci produce a single `____` entry (code `-`), mirroring the
/// desktop app's `fillna("____")`.
List<CartellinoEntry> explodeRows(List<CartellinoRow> rows, int year) {
  final entries = <CartellinoEntry>[];
  for (final row in rows) {
    final date = parseCartellinoDate(row.data, year);
    final voci = row.vociBase.isEmpty ? const ['____'] : row.vociBase;
    for (final voce in voci) {
      entries.add(CartellinoEntry(
        stato: row.stato,
        data: row.data,
        date: date,
        voce: voce,
        codice: extractCodice(voce),
      ));
    }
  }
  return entries;
}
