import '../domain/period.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "Wed 14 Oct", "Week 42", "October 2026". Hand-rolled to avoid adding
/// `intl` for three English formats.
String periodLabel(Period period) => switch (period) {
  Day(:final date) => dayLabel(date),
  Week(:final week) => 'Week $week',
  Month(:final year, :final month) => '${_months[month - 1]} $year',
};

String dayLabel(DateTime d) =>
    '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1].substring(0, 3)}';

String timeLabel(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String dateTimeLabel(DateTime t) => '${dayLabel(t)} ${timeLabel(t)}';
