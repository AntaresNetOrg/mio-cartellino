/// User settings (subset of the desktop app's `config.toml`).
library;

import 'excluded_date.dart';

class AppSettings {
  const AppSettings({
    required this.year,
    required this.minDateMonth,
    required this.minDateDay,
    this.exceptionCodes = defaultExceptionCodes,
    this.balanceCodes = defaultBalanceCodes,
    this.excludedDates = const [],
  });

  factory AppSettings.defaults(DateTime now) =>
      AppSettings(year: now.year, minDateMonth: 1, minDateDay: 1);

  static const defaultExceptionCodes = ['ERIT', 'SCN'];
  static const defaultBalanceCodes = ['CRE', 'OE-DIU', 'SCN'];

  /// Year to download and process: always the current calendar year, so it isn't
  /// persisted (unlike desktop `current_year`). The app has no use for past years.
  final int year;

  /// Riposi used (SRC) are counted strictly after this day of [year]
  /// (desktop: `min_date_riposi_usati`, `MM-DD`).
  final int minDateMonth;
  final int minDateDay;

  /// Desktop: `dashboard_exception_codes`.
  final List<String> exceptionCodes;

  /// Desktop: `dashboard_balance_codes`.
  final List<String> balanceCodes;

  /// Desktop: `date_escluse.txt`.
  final List<ExcludedDate> excludedDates;

  DateTime get minDate => DateTime(year, minDateMonth, minDateDay);

  AppSettings copyWith({
    int? minDateMonth,
    int? minDateDay,
    List<String>? exceptionCodes,
    List<String>? balanceCodes,
    List<ExcludedDate>? excludedDates,
  }) =>
      AppSettings(
        year: year,
        minDateMonth: minDateMonth ?? this.minDateMonth,
        minDateDay: minDateDay ?? this.minDateDay,
        exceptionCodes: exceptionCodes ?? this.exceptionCodes,
        balanceCodes: balanceCodes ?? this.balanceCodes,
        excludedDates: excludedDates ?? this.excludedDates,
      );

  /// A `year` key saved by older versions is ignored.
  factory AppSettings.fromJson(Map<String, dynamic> json, {required int year}) => AppSettings(
        year: year,
        minDateMonth: json['minDateMonth'] as int,
        minDateDay: json['minDateDay'] as int,
        exceptionCodes: (json['exceptionCodes'] as List<dynamic>?)?.cast<String>() ??
            defaultExceptionCodes,
        balanceCodes:
            (json['balanceCodes'] as List<dynamic>?)?.cast<String>() ?? defaultBalanceCodes,
        excludedDates: [
          for (final s in (json['excludedDates'] as List<dynamic>? ?? const []))
            ExcludedDate.parse(s as String),
        ],
      );

  Map<String, dynamic> toJson() => {
        'minDateMonth': minDateMonth,
        'minDateDay': minDateDay,
        'exceptionCodes': exceptionCodes,
        'balanceCodes': balanceCodes,
        // Stored in the desktop text format, so it round-trips with date_escluse.txt.
        'excludedDates': [for (final e in excludedDates) e.format()],
      };
}
