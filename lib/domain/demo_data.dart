/// Fictitious cartellino for the demo mode, which lets store reviewers try the app
/// without a SPID or CIE login. Contains no real data.
library;

import 'cartellino.dart';
import 'riposi.dart';

const _days = ['lun', 'mar', 'mer', 'gio', 'ven', 'sab', 'dom'];
const _months = [
  'gen',
  'feb',
  'mar',
  'apr',
  'mag',
  'giu',
  'lug',
  'ago',
  'set',
  'ott',
  'nov',
  'dic'
];
const _ordinary = 'OO-DIU 07.12';

/// One row per day from January 1st to [now], in the portal's format.
List<CartellinoRow> demoRows(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final past = <DateTime>[];
  final thisMonth = <DateTime>[];
  for (var d = DateTime(now.year); d.isBefore(today); d = DateTime(d.year, d.month, d.day + 1)) {
    if (d.weekday > DateTime.friday) continue;
    (d.month == now.month ? thisMonth : past).add(d);
  }

  final voci = <DateTime, List<String>>{};
  for (var i = 4; i < past.length; i += 9) {
    voci[past[i]] = [_ordinary, 'OE-DIU 01.15'];
  }
  const absences = {
    10: 'FER',
    11: 'FER',
    12: 'FER',
    30: 'FER',
    31: 'FER',
    70: 'FER',
    71: 'FER',
    72: 'FER',
    73: 'FER',
    74: 'FER',
    75: 'FER',
    76: 'FER',
    5: 'FEV',
    6: 'FEV',
    7: 'FEV',
    50: 'FST',
    51: 'FST',
    90: 'PMF',
    120: 'SRC',
  };
  absences.forEach((index, code) {
    if (index < past.length) voci[past[index]] = ['$code 07.12'];
  });
  const monthExtras = ['ERIT 00.12', 'OE-DIU 00.55', 'SCN 00.10'];
  for (var i = 0; i < monthExtras.length && i < thisMonth.length; i++) {
    voci[thisMonth[i]] = [_ordinary, monthExtras[i]];
  }

  return [
    for (var d = DateTime(now.year); !d.isAfter(today); d = DateTime(d.year, d.month, d.day + 1))
      CartellinoRow(
        stato: statoConfermato,
        data: '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}',
        vociBase: voci[d] ??
            (d.weekday <= DateTime.friday && d.isBefore(today) ? const [_ordinary] : const []),
      ),
  ];
}
