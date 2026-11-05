import 'dart:io';

import 'package:cartellino_unisa_mobile/data/stores.dart';
import 'package:cartellino_unisa_mobile/domain/cartellino.dart';
import 'package:cartellino_unisa_mobile/domain/dashboard.dart';
import 'package:cartellino_unisa_mobile/domain/demo_data.dart';
import 'package:cartellino_unisa_mobile/domain/settings.dart';
import 'package:cartellino_unisa_mobile/services.dart';
import 'package:cartellino_unisa_mobile/ui/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('demo data', () {
    for (final now in [DateTime(2026, 1, 1), DateTime(2026, 1, 15), DateTime(2026, 11, 5)]) {
      test('produces a complete summary on $now', () {
        final rows = demoRows(now);
        expect(rows, hasLength(now.difference(DateTime(2026)).inDays + 1));
        final summary = DashboardSummary.compute(
          entries: explodeRows(rows, now.year),
          settings: AppSettings.defaults(now),
          now: now,
        );
        expect(summary.errors, isEmpty);
      });
    }

    test('in November shows a positive balance and exceptions', () {
      final now = DateTime(2026, 11, 5);
      final summary = DashboardSummary.compute(
        entries: explodeRows(demoRows(now), 2026),
        settings: AppSettings.defaults(now),
        now: now,
      );
      expect(summary.saldoMeseMinuti, 45);
      expect(summary.eccezioni!.map((e) => e.codice), ['ERIT', 'SCN']);
    });
  });

  group('demo mode', () {
    late Directory directory;
    late AppServices services;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('cartellino_demo');
      services = AppServices.forTesting(JsonStore(directory));
    });
    tearDown(() => directory.deleteSync(recursive: true));

    /// Lets real file I/O complete, then rebuilds.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 30; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump();
      }
    }

    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: DashboardScreen(services: services)));
      await settle(tester);
    }

    testWidgets('starts from an empty install, is labelled, and can be left', (tester) async {
      await open(tester);
      await tester.tap(find.text('Prova con dati dimostrativi'));
      await settle(tester);
      final stored = await tester.runAsync(() => services.cartellino.load(DateTime.now().year));
      expect(stored!.isDemo, isTrue);
      expect(find.textContaining('Dati dimostrativi'), findsOneWidget);
      expect(find.text('Riposi compensativi'), findsOneWidget);

      await tester.tap(find.text('Esci dalla demo'));
      await settle(tester);
      expect(find.text('Scarica cartellino'), findsOneWidget);
      expect(find.textContaining('Dati dimostrativi'), findsNothing);
    });

    testWidgets('is not offered when a real cartellino is stored', (tester) async {
      final now = DateTime.now();
      await tester.runAsync(() => services.cartellino.save(
            StoredCartellino(year: now.year, fetchedAt: now, rows: const []),
          ));
      await open(tester);
      expect(find.text('Prova con dati dimostrativi'), findsNothing);
      expect(find.textContaining('Dati dimostrativi'), findsNothing);
    });
  });
}
