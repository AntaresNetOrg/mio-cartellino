/// Ore eccedenti (OE-DIU) and riposi compensativi.
///
/// Port of `cartellino/ore_eccedenti.py` (`_elabora`,
/// `_raggruppa_ore_eccedenti`, `get_date_usate_from_src`) and of
/// `_categorizza_riposo` in `cartellino/tui/screens/dashboard.py`.
/// Keep the grouping algorithm identical to the desktop app, quirks included
/// (see CLAUDE.md § "Porting notes"), so both apps show the same riposi.
library;

import 'cartellino.dart';
import 'clock.dart';
import 'excluded_date.dart';
import 'ore.dart';

/// Minutes of ore eccedenti needed for one riposo compensativo (7:12).
const minutiPerRiposo = 7 * 60 + 12;

/// Stato value meaning "processed and confirmed" by the HR system.
const statoConfermato = 'ELAB P1';

class OreEccedentiGiorno {
  const OreEccedentiGiorno({required this.entry, required this.minuti});
  final CartellinoEntry entry;
  final int minuti;
}

class OreInserite {
  const OreInserite({
    required this.data,
    required this.date,
    required this.minuti,
    required this.stato,
  });

  factory OreInserite.from(OreEccedentiGiorno o, int minuti) => OreInserite(
      data: o.entry.data, date: o.entry.date, minuti: minuti, stato: o.entry.stato);

  final String data;
  final DateTime date;
  final int minuti;
  final String stato;

  bool get confermata => stato == statoConfermato;
}

class RiposoCompensativo {
  RiposoCompensativo({
    required this.id,
    this.minutiNecessari = minutiPerRiposo,
    List<OreInserite>? ore,
  }) : ore = ore ?? [];

  final int id;
  final int minutiNecessari;
  final List<OreInserite> ore;

  /// Date (`dd-MM-yyyy`) on which the riposo was used, if any.
  String? dataUso;

  int get minutiInseriti => ore.fold(0, (sum, o) => sum + o.minuti);
  int get minutiMancanti => minutiNecessari - minutiInseriti;
}

enum StatoRiposo { usato, completoConfermato, completoNonConfermato, daCompletare }

StatoRiposo statoRiposo(RiposoCompensativo r) {
  if (r.dataUso != null) return StatoRiposo.usato;
  if (r.minutiMancanti <= 0) {
    return r.ore.every((o) => o.confermata)
        ? StatoRiposo.completoConfermato
        : StatoRiposo.completoNonConfermato;
  }
  return StatoRiposo.daCompletare;
}

/// OE-DIU entries with excluded dates applied.
///
/// NOTE: the desktop app matches partial exclusions with a pandas
/// datetime-vs-string comparison that swaps day and month when day <= 12
/// (verified with pandas 3.0.5: `03-04-2025` matches 4 March). Here we match
/// by calendar day, i.e. the intended behaviour. See CLAUDE.md.
List<OreEccedentiGiorno> oreEccedenti(
  List<CartellinoEntry> entries,
  List<ExcludedDate> excluded,
) {
  final fullDays = {for (final e in excluded) if (e.isFullDay) dayOf(e.date)};
  final partial = {
    for (final e in excluded)
      if (!e.isFullDay) dayOf(e.date): e.subtractMinutes!,
  };
  return [
    for (final e in entries)
      if (e.codice == 'OE-DIU' && !fullDays.contains(dayOf(e.date)))
        OreEccedentiGiorno(
          entry: e,
          minuti: _minuti(e.voce) - (partial[dayOf(e.date)] ?? 0),
        ),
  ];
}

int _minuti(String voce) {
  final (h, m) = estraiOreMinuti(voce);
  return h * 60 + m;
}

/// Groups ore eccedenti into riposi of [minutiNecessari] each, in order,
/// assigning [dateUsate] (oldest first) to the riposi as they complete.
/// Always returns at least one (possibly empty) riposo, like the desktop app.
List<RiposoCompensativo> raggruppaRiposi(
  List<OreEccedentiGiorno> ore,
  List<String> dateUsate, {
  int minutiNecessari = minutiPerRiposo,
}) {
  final usati = [...dateUsate];
  final riposi = <RiposoCompensativo>[];
  var corrente = RiposoCompensativo(id: 1, minutiNecessari: minutiNecessari);
  for (final o in ore) {
    final mancanti = corrente.minutiMancanti;
    if (mancanti >= o.minuti) {
      corrente.ore.add(OreInserite.from(o, o.minuti));
    } else {
      corrente.ore.add(OreInserite.from(o, mancanti));
      if (usati.isNotEmpty) corrente.dataUso = usati.removeAt(0);
      riposi.add(corrente);
      corrente = RiposoCompensativo(
        id: corrente.id + 1,
        minutiNecessari: minutiNecessari,
        ore: [OreInserite.from(o, o.minuti - mancanti)],
      );
    }
  }
  riposi.add(corrente);
  return riposi;
}

/// Dates (`dd-MM-yyyy`) of riposi already used: SRC entries strictly after
/// [minDate].
List<String> dateUsateDaSrc(List<CartellinoEntry> entries, DateTime minDate) => [
      for (final e in entries)
        if (e.codice == 'SRC' && e.date.isAfter(minDate)) formatDateDash(e.date),
    ];
