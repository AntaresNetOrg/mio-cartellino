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
///   needed, which is a WARNING, never a block. The sliders stop at meaningful
///   values but can always be forced past them;
/// * minutes after 19:50 are not counted as excess, which is also a WARNING;
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
    this.latestCountedExit = 19 * 60 + 50,
    this.maxCreditUsed = 60,
    this.maxDebtRecovered = 120,
  });

  /// Earliest time from which presence is counted (07:50).
  final int minEntry;

  /// Required presence including the 10' pause (07:22).
  final int dailyPresence;

  /// Max minutes of credit use / debt recovery per day without a permit.
  final int tolerance;

  /// Excess minutes are not counted after this time (19:50).
  final int latestCountedExit;

  /// Leaving more than this much earlier needs a permit, so it isn't handled here.
  final int maxCreditUsed;

  /// Upper limit of the debt recovery slider.
  final int maxDebtRecovered;

  static const unisa = WorkRules();
}

enum ExitTimeWarning {
  /// Credit used beyond [WorkRules.tolerance]: a permit is needed.
  creditOverTolerance,

  /// Debt recovered beyond [WorkRules.tolerance]: a permit is needed.
  debtOverTolerance,

  /// Credit used exceeds the available monthly balance.
  creditExceedsBalance,

  /// Exit after [WorkRules.latestCountedExit]: later minutes are not counted.
  exitAfterLatestCounted,
}

enum AdjustStopKind {
  /// All of the monthly excess, or all of the monthly shortfall.
  balance,

  /// [WorkRules.tolerance].
  tolerance,

  /// The amount of debt recovery that leads to [WorkRules.latestCountedExit].
  latestCountedExit,
}

/// A value where the credit / debt slider stops.
class AdjustStop {
  const AdjustStop(this.minutes, this.kind);
  final int minutes;
  final AdjustStopKind kind;
}

List<AdjustStop> _normalizedStops(List<AdjustStop> stops, int max) {
  final seen = <int>{};
  return stops.where((s) => s.minutes > 0 && s.minutes <= max && seen.add(s.minutes)).toList()
    ..sort((a, b) => a.minutes.compareTo(b.minutes));
}

/// Stops of the credit slider: the monthly excess [balance], if any, and the tolerance.
List<AdjustStop> creditStops({int? balance, WorkRules rules = WorkRules.unisa}) =>
    _normalizedStops([
      if (balance != null) AdjustStop(balance, AdjustStopKind.balance),
      AdjustStop(rules.tolerance, AdjustStopKind.tolerance),
    ], rules.maxCreditUsed);

/// Stops of the debt slider: the monthly shortfall (negative [balance]), the
/// tolerance and the recovery that reaches 19:50. [baseExit] is the expected exit
/// with no adjustment, if known.
List<AdjustStop> debtStops({int? balance, int? baseExit, WorkRules rules = WorkRules.unisa}) =>
    _normalizedStops([
      if (balance != null) AdjustStop(-balance, AdjustStopKind.balance),
      AdjustStop(rules.tolerance, AdjustStopKind.tolerance),
      if (baseExit != null)
        AdjustStop(rules.latestCountedExit - baseExit, AdjustStopKind.latestCountedExit),
    ], rules.maxDebtRecovered);

/// The slider value for a drag from [current] to [raw]. The value stays on the first
/// of the ascending [stops] it reaches until [raw] is at least [release] minutes away
/// from it, in either direction. Every value stays reachable: those just past a stop
/// can be selected coming back from the other side.
int valueWithStops({
  required int current,
  required int raw,
  required List<int> stops,
  int release = 4,
}) {
  var position = current;
  while (true) {
    if (stops.contains(position) && (raw - position).abs() < release) return position;
    final ahead = raw > position
        ? stops.where((s) => s > position && s <= raw)
        : stops.reversed.where((s) => s < position && s >= raw);
    if (ahead.isEmpty) return raw;
    position = ahead.first;
  }
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

  final countedStart = effective.first > rules.minEntry ? effective.first : rules.minEntry;

  // Each (exit, re-entry) pair; only the part after minEntry counts.
  var absence = 0;
  for (var i = 1; i + 1 < effective.length; i += 2) {
    final out = effective[i];
    final back = effective[i + 1];
    final from = out > rules.minEntry ? out : rules.minEntry;
    if (back > from) absence += back - from;
  }

  final exitAt = countedStart + rules.dailyPresence + absence - creditUsed + debtRecovered;

  final warnings = <ExitTimeWarning>[
    if (creditUsed > rules.tolerance) ExitTimeWarning.creditOverTolerance,
    if (debtRecovered > rules.tolerance) ExitTimeWarning.debtOverTolerance,
    if (creditUsed > 0 &&
        availableCredit != null &&
        creditUsed > (availableCredit > 0 ? availableCredit : 0))
      ExitTimeWarning.creditExceedsBalance,
    if (exitAt > rules.latestCountedExit) ExitTimeWarning.exitAfterLatestCounted,
  ];

  return ExitTimeResult(
    exitAt: exitAt,
    provisional: provisional,
    countedStart: countedStart,
    absenceMinutes: absence,
    warnings: warnings,
  );
}
