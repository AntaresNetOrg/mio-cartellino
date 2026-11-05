/// "Uscita prevista" — expected clock-out time for today.
///
/// Mobile-only feature (not in the desktop app). Rules agreed with the
/// product owner, see CLAUDE.md § "Exit time rules":
///
/// * required daily presence is 7:22, which already includes the 10' lunch
///   pause;
/// * presence counts from 07:50 at the earliest (earlier punches are clamped);
/// * every intermediate exit → re-entry interval is added in full (the 10'
///   pause is NOT absorbed by it);
/// * the user may explicitly use part of the monthly credit (leave earlier) or
///   recover missing minutes (leave later); beyond 29' per day a permit is
///   needed, which is a WARNING, never a block;
/// * if the last punch is an exit (user currently out), the result is
///   provisional and assumes re-entry at [now].
library;

/// Working-time rules. Defaults are UniSA's; kept configurable for tests and
/// for a future settings screen.
class WorkRules {
  const WorkRules({
    this.minEntry = 7 * 60 + 50,
    this.dailyPresence = 7 * 60 + 22,
    this.tolerance = 29,
  });

  /// Earliest time from which presence is counted (07:50).
  final int minEntry;

  /// Required presence including the 10' pause (07:22).
  final int dailyPresence;

  /// Max minutes of credit use / debt recovery per day without a permit.
  final int tolerance;

  static const unisa = WorkRules();
}

enum ExitTimeWarning {
  /// Credit used beyond [WorkRules.tolerance]: a permit is needed.
  creditOverTolerance,

  /// Debt recovered beyond [WorkRules.tolerance]: a permit is needed.
  debtOverTolerance,

  /// Credit used exceeds the available monthly balance.
  creditExceedsBalance,
}

class ExitTimeResult {
  const ExitTimeResult({
    required this.exitAt,
    required this.provisional,
    required this.countedStart,
    required this.absenceMinutes,
    required this.warnings,
  });

  /// Expected exit, minutes since midnight.
  final int exitAt;

  /// True when the user is currently out and re-entry was assumed at `now`.
  final bool provisional;

  /// First counted minute of presence (first entry, clamped to 07:50).
  final int countedStart;

  /// Total minutes of intermediate absences added to the day.
  final int absenceMinutes;

  final List<ExitTimeWarning> warnings;
}

class InvalidPunchesException implements Exception {
  const InvalidPunchesException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Computes the expected exit time.
///
/// [punches] are today's clock events in minutes since midnight, strictly
/// increasing, alternating entry/exit and starting with an entry.
/// [creditUsed] (leave earlier) and [debtRecovered] (leave later) are
/// non-negative minutes. [availableCredit] is the current monthly balance,
/// if known, used only for the [ExitTimeWarning.creditExceedsBalance] check.
/// [now] is required when the last punch is an exit.
ExitTimeResult computeExitTime({
  required List<int> punches,
  int creditUsed = 0,
  int debtRecovered = 0,
  int? availableCredit,
  int? now,
  WorkRules rules = WorkRules.unisa,
}) {
  if (punches.isEmpty) {
    throw const InvalidPunchesException('Nessuna timbratura inserita.');
  }
  if (creditUsed < 0 || debtRecovered < 0) {
    throw ArgumentError('creditUsed and debtRecovered must be >= 0');
  }
  for (var i = 1; i < punches.length; i++) {
    if (punches[i] <= punches[i - 1]) {
      throw InvalidPunchesException(
          'Le timbrature devono essere in ordine crescente (posizione ${i + 1}).');
    }
  }

  final provisional = punches.length.isEven;
  final effective = [...punches];
  if (provisional) {
    if (now == null) {
      throw const InvalidPunchesException(
          'Risulti fuori sede: serve l\'ora attuale per stimare il rientro.');
    }
    // Re-entry "now", but never before the last exit.
    effective.add(now > punches.last ? now : punches.last);
  }

  final countedStart =
      effective.first > rules.minEntry ? effective.first : rules.minEntry;

  // Each (exit, re-entry) pair; only the part after minEntry counts.
  var absence = 0;
  for (var i = 1; i + 1 < effective.length; i += 2) {
    final out = effective[i];
    final back = effective[i + 1];
    final from = out > rules.minEntry ? out : rules.minEntry;
    if (back > from) absence += back - from;
  }

  final warnings = <ExitTimeWarning>[
    if (creditUsed > rules.tolerance) ExitTimeWarning.creditOverTolerance,
    if (debtRecovered > rules.tolerance) ExitTimeWarning.debtOverTolerance,
    if (creditUsed > 0 &&
        availableCredit != null &&
        creditUsed > (availableCredit > 0 ? availableCredit : 0))
      ExitTimeWarning.creditExceedsBalance,
  ];

  return ExitTimeResult(
    exitAt: countedStart + rules.dailyPresence + absence - creditUsed + debtRecovered,
    provisional: provisional,
    countedStart: countedStart,
    absenceMinutes: absence,
    warnings: warnings,
  );
}
