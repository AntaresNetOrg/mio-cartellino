import 'package:cartellino_unisa_mobile/domain/cartellino.dart';
import 'package:cartellino_unisa_mobile/domain/excluded_date.dart';
import 'package:cartellino_unisa_mobile/domain/ore.dart';
import 'package:cartellino_unisa_mobile/domain/riposi.dart';
import 'package:flutter_test/flutter_test.dart';

CartellinoRow row(String data, List<String> voci, {String stato = statoConfermato}) =>
    CartellinoRow(stato: stato, data: data, vociBase: voci);

void main() {
  group('parsing', () {
    test('portal date', () {
      expect(parseCartellinoDate('lun 6 gen', 2026), DateTime(2026, 1, 6));
      expect(parseCartellinoDate('Ven 13 Mar', 2026), DateTime(2026, 3, 13));
    });
    test('impossible date is rejected', () {
      expect(() => parseCartellinoDate('lun 30 feb', 2026), throwsFormatException);
    });
    test('codice', () {
      expect(extractCodice('OE-DIU 02.30'), 'OE-DIU');
      expect(extractCodice('SCN 00.26'), 'SCN');
      expect(extractCodice('____'), '-');
    });
    test('explode keeps one entry per voce', () {
      final entries = explodeRows([
        row('lun 5 gen', ['OO-DIU 07.12', 'OE-DIU 00.30']),
        row('mar 6 gen', []),
      ], 2026);
      expect(entries.map((e) => e.codice), ['OO-DIU', 'OE-DIU', '-']);
    });
    test('ore/minuti', () => expect(estraiOreMinuti('OE-DIU 02.30'), (2, 30)));
  });

  group('saldo', () {
    test('SCN is subtracted (desktop issue #8)', () {
      final entries = explodeRows([
        row('lun 5 gen', ['CRE 00.07']),
        row('mar 6 gen', ['SCN 00.26']),
      ], 2026);
      expect(saldoMinuti(entries, ['CRE', 'OE-DIU', 'SCN']), -19);
    });
  });

  group('excluded dates', () {
    test('parse desktop format', () {
      expect(ExcludedDate.parse('16-01-2025').isFullDay, isTrue);
      expect(ExcludedDate.parse('20-01-2025 03:30').subtractMinutes, 210);
      expect(() => ExcludedDate.parse('2025-01-16'), throwsFormatException);
    });
    test('day <= 12 is not swapped with month', () {
      final entries = explodeRows([
        row('gio 3 apr', ['OE-DIU 02.00']),
        row('mar 4 mar', ['OE-DIU 02.00']),
      ], 2025);
      final oe = oreEccedenti(entries, [ExcludedDate.parse('03-04-2025 01:00')]);
      expect(oe.map((o) => o.minuti), [60, 120]);
    });
    test('full-day exclusion drops the day', () {
      final entries = explodeRows([row('lun 5 gen', ['OE-DIU 02.00'])], 2026);
      expect(oreEccedenti(entries, [ExcludedDate.parse('05-01-2026')]), isEmpty);
    });
  });

  group('riposi', () {
    test('grouping splits the day that completes a riposo', () {
      // 3:00 + 3:00 + 2:00 -> riposo 1 = 3:00 + 3:00 + 1:12, riposo 2 = 0:48.
      final entries = explodeRows([
        row('lun 5 gen', ['OE-DIU 03.00']),
        row('mar 6 gen', ['OE-DIU 03.00']),
        row('mer 7 gen', ['OE-DIU 02.00'], stato: 'ELAB GG'),
      ], 2026);
      final riposi = raggruppaRiposi(oreEccedenti(entries, const []), const []);
      expect(riposi.length, 2);
      expect(riposi[0].minutiMancanti, 0);
      expect(riposi[0].ore.map((o) => o.minuti), [180, 180, 72]);
      expect(riposi[1].minutiMancanti, 384); // 6:24
      expect(statoRiposo(riposi[0]), StatoRiposo.completoNonConfermato);
      expect(statoRiposo(riposi[1]), StatoRiposo.daCompletare);
    });

    test('used dates come from SRC after the min date and are assigned in order', () {
      final entries = explodeRows([
        row('lun 5 gen', ['OE-DIU 05.00']),
        row('mar 6 gen', ['OE-DIU 05.00']),
        row('ven 9 gen', ['SRC 07.12']),
      ], 2026);
      final usati = dateUsateDaSrc(entries, DateTime(2026, 1, 1));
      expect(usati, ['09-01-2026']);
      final riposi = raggruppaRiposi(oreEccedenti(entries, const []), usati);
      expect(statoRiposo(riposi[0]), StatoRiposo.usato);
      expect(riposi[0].dataUso, '09-01-2026');
    });

    test('no ore eccedenti -> one empty riposo', () {
      final riposi = raggruppaRiposi(const [], const []);
      expect(riposi.single.minutiMancanti, minutiPerRiposo);
    });
  });
}
