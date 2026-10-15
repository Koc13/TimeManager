import '../domain/aggregation.dart';
import '../domain/habit.dart';
import '../domain/period.dart';
import '../domain/recurring.dart';

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

/// "30 pages" or "2.5 km": whole numbers without a trailing ".0".
String amountLabel(num n, String? unit) {
  final value = n == n.roundToDouble() ? '${n.round()}' : '$n';
  return unit == null ? value : '$value $unit';
}

/// One habit's line on a Done page. A day shows the value ("Reading: 30
/// pages", "Gym ✓"); longer periods add the day count.
String habitSummary(Habit? habit, HabitTotal total, {required bool singleDay}) {
  final name = habit?.title ?? '(deleted habit)';
  final days = total.days == 1 ? '1 day' : '${total.days} days';
  if (habit?.kind == HabitKind.measurable) {
    final amount = amountLabel(total.total, habit!.unit);
    return singleDay ? '$name: $amount' : '$name: $amount on $days';
  }
  return singleDay ? '$name ✓' : '$name: $days';
}

/// "70 min" / "1 h 10 min".
String minutesLabel(int minutes) =>
    minutes < 60 ? '$minutes min' : '${minutes ~/ 60} h ${minutes % 60} min';

String weekdayShort(int weekday) => _weekdays[weekday - 1];

/// "Repeat" / "Every day" / "Mon, Wed, Fri" / "Monthly on day 15".
String repeatLabel(RepeatRule? rule) => switch (rule?.every) {
  null => 'Repeat',
  RepeatEvery.day => 'Every day',
  RepeatEvery.weekdays =>
    (rule!.weekdays.toList()..sort()).map(weekdayShort).join(', '),
  RepeatEvery.week => 'Every week',
  RepeatEvery.month =>
    rule!.dayOfMonth == null
        ? 'Every month'
        : 'Monthly on day ${rule.dayOfMonth}',
};

const _weekdaysLong = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String weekdayLong(int weekday) => _weekdaysLong[weekday - 1];
