/// Dashboard summary. Port of the sections of
/// `cartellino/tui/screens/dashboard.py` selected for mobile:
/// eccezioni del mese, saldo del mese, riposi compensativi, ferie/PMF,
/// ultimo aggiornamento. (Ticket da ricevere: not in the mobile MVP.)
///
/// Each section is computed independently: an error in one (e.g. a voce
/// without `HH.MM`) is reported in [DashboardSummary.errors] instead of
/// breaking the whole dashboard, as the desktop app does.
library;

import 'cartellino.dart';
import 'ore.dart';
import 'riposi.dart';
import 'settings.dart';

class Eccezione {
  const Eccezione({required this.date, required this.codice, required this.minuti});
  final DateTime date;
  final String codice;

  /// Null when the voce has no `HH.MM` value.
  final int? minuti;
}

class FerieCounts {
  const FerieCounts({
    required this.ferieAnnoCorrente,
    required this.ferieAnniPrecedenti,
    required this.festivitaSoppresse,
    required this.permessiGraviMotivi,
  });
  final int ferieAnnoCorrente; // FER
  final int ferieAnniPrecedenti; // FEV
  final int festivitaSoppresse; // FST
  final int permessiGraviMotivi; // PMF
}

class DashboardSummary {
  const DashboardSummary({
    required this.month,
    required this.lastUpdate,
    required this.eccezioni,
    required this.saldoMeseMinuti,
    required this.riposi,
    required this.ferie,
    required this.errors,
  });

  /// Any day in the month the summary refers to.
  final DateTime month;
  final DateTime? lastUpdate;
  final List<Eccezione>? eccezioni;
  final int? saldoMeseMinuti;
  final List<RiposoCompensativo>? riposi;
  final FerieCounts? ferie;

  /// Section name -> error message.
  final Map<String, String> errors;

  static DashboardSummary compute({
    required List<CartellinoEntry> entries,
    required AppSettings settings,
    required DateTime now,
    DateTime? lastUpdate,
  }) {
    final errors = <String, String>{};
    T? guard<T>(String section, T Function() fn) {
      try {
        return fn();
      } catch (e) {
        errors[section] = e.toString();
        return null;
      }
    }

    final month = inMonth(entries, now).toList();

    final eccezioni = guard('eccezioni', () {
      final codes = settings.exceptionCodes.toSet();
      return [
        for (final e in month)
          if (codes.contains(e.codice))
            Eccezione(date: e.date, codice: e.codice, minuti: tryMinuti(e.voce)),
      ];
    });

    final saldo = guard('saldo', () => saldoMinuti(month, settings.balanceCodes));

    final riposi = guard('riposi', () {
      final oe = oreEccedenti(entries, settings.excludedDates);
      final usati = dateUsateDaSrc(entries, settings.minDate);
      return raggruppaRiposi(oe, usati);
    });

    final ferie = guard('ferie', () {
      int count(String code) => entries.where((e) => e.codice == code).length;
      return FerieCounts(
        ferieAnnoCorrente: count('FER'),
        ferieAnniPrecedenti: count('FEV'),
        festivitaSoppresse: count('FST'),
        permessiGraviMotivi: count('PMF'),
      );
    });

    return DashboardSummary(
      month: now,
      lastUpdate: lastUpdate,
      eccezioni: eccezioni,
      saldoMeseMinuti: saldo,
      riposi: riposi,
      ferie: ferie,
      errors: errors,
    );
  }
}
