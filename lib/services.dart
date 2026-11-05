import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'data/stores.dart';

/// App-wide services, created once in `main()` and passed down explicitly.
/// Deliberately no state-management package for the MVP.
class AppServices {
  AppServices._(JsonStore store)
      : settings = SettingsStore(store),
        cartellino = CartellinoRepository(store),
        punches = TodayPunchesStore(store);

  @visibleForTesting
  AppServices.forTesting(JsonStore store) : this._(store);

  static Future<AppServices> create() async =>
      AppServices._(JsonStore(await getApplicationDocumentsDirectory()));

  final SettingsStore settings;
  final CartellinoRepository cartellino;
  final TodayPunchesStore punches;

  /// Bumped whenever settings or the cached cartellino change; screens listen
  /// to it to reload.
  final revision = ValueNotifier<int>(0);

  void notifyChanged() => revision.value++;
}
