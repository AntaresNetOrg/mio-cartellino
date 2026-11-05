import 'package:cartellino_unisa_mobile/domain/clock.dart';
import 'package:cartellino_unisa_mobile/domain/exit_time.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cases agreed with the product owner (see CLAUDE.md § "Exit time rules").
void main() {
  String exit(List<int> punches, {int credit = 0, int debt = 0, int? now, int? balance}) =>
      formatHm(computeExitTime(
        punches: punches,
        creditUsed: credit,
        debtRecovered: debt,
        now: now,
        availableCredit: balance,
      ).exitAt);

  group('base cases', () {
    test('entry at 07:50 -> 15:12', () => expect(exit([hm(7, 50)]), '15:12'));
    test('entry before 07:50 is clamped', () => expect(exit([hm(7, 30)]), '15:12'));
    test('entry at 08:15 -> 15:37', () => expect(exit([hm(8, 15)]), '15:37'));
    test('intermediate exit is added in full (pause not absorbed)', () {
      expect(exit([hm(7, 50), hm(13, 0), hm(13, 30)]), '15:42');
    });
    test('absence before 07:50 is ignored', () {
      // In 07:20, out 07:30, back 07:40: presence still counts from 07:50.
      expect(exit([hm(7, 20), hm(7, 30), hm(7, 40)]), '15:12');
    });
    test('absence straddling 07:50 counts only after 07:50', () {
      // In 07:20, out 07:40, back 08:00: 10' counted.
      expect(exit([hm(7, 20), hm(7, 40), hm(8, 0)]), '15:22');
    });
  });

  group('credit / debt adjustments', () {
    test('use 20\' of credit', () => expect(exit([hm(8, 15)], credit: 20), '15:17'));
    test('recover 29\' of debt', () => expect(exit([hm(8, 15)], debt: 29), '16:06'));

    test('29\' is within tolerance: no warning', () {
      final r = computeExitTime(punches: [hm(8, 15)], creditUsed: 29);
      expect(r.warnings, isEmpty);
    });

    test('over 29\' of credit: computed anyway, with warning', () {
      final r = computeExitTime(punches: [hm(8, 15)], creditUsed: 40);
      expect(formatHm(r.exitAt), '14:57');
      expect(r.warnings, [ExitTimeWarning.creditOverTolerance]);
    });

    test('over 29\' of debt: computed anyway, with warning', () {
      final r = computeExitTime(punches: [hm(8, 15)], debtRecovered: 35);
      expect(formatHm(r.exitAt), '16:12');
      expect(r.warnings, [ExitTimeWarning.debtOverTolerance]);
    });

    test('credit above monthly balance: warning', () {
      final r = computeExitTime(punches: [hm(8, 15)], creditUsed: 25, availableCredit: 20);
      expect(r.warnings, [ExitTimeWarning.creditExceedsBalance]);
    });

    test('negative balance: any credit use warns', () {
      final r = computeExitTime(punches: [hm(8, 15)], creditUsed: 5, availableCredit: -10);
      expect(r.warnings, [ExitTimeWarning.creditExceedsBalance]);
    });
  });

  group('currently out', () {
    test('assumes re-entry now and is provisional', () {
      final r = computeExitTime(punches: [hm(7, 50), hm(13, 0)], now: hm(13, 20));
      expect(r.provisional, isTrue);
      expect(r.absenceMinutes, 20);
      expect(formatHm(r.exitAt), '15:32');
    });

    test('requires now', () {
      expect(
        () => computeExitTime(punches: [hm(7, 50), hm(13, 0)]),
        throwsA(isA<InvalidPunchesException>()),
      );
    });
  });

  group('validation', () {
    test('empty punches', () {
      expect(() => computeExitTime(punches: []), throwsA(isA<InvalidPunchesException>()));
    });
    test('non increasing punches', () {
      expect(
        () => computeExitTime(punches: [hm(8, 0), hm(7, 0), hm(9, 0)]),
        throwsA(isA<InvalidPunchesException>()),
      );
    });
  });
}
