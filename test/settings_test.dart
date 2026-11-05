import 'package:cartellino_unisa_mobile/domain/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the year is not persisted and a saved one is ignored', () {
    final saved = AppSettings.defaults(DateTime(2026, 11, 5)).toJson();
    expect(saved.containsKey('year'), isFalse);

    final loaded = AppSettings.fromJson({...saved, 'year': 2025}, year: 2027);
    expect(loaded.year, 2027);
    expect(loaded.minDate, DateTime(2027, 1, 1));
  });
}
