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

/// "70 min" → "1 h 10 min"; "2 h" when the minutes are 0.
String minutesLabel(int minutes) => minutes < 60
    ? '$minutes min'
    : minutes % 60 == 0
    ? '${minutes ~/ 60} h'
    : '${minutes ~/ 60} h ${minutes % 60} min';

/// A habit's amount for a period's "Logged" list: "30 pages", "✓", or
/// "3 days" / "120 pages · 5 days" over a longer period.
String habitAmount(Habit? habit, HabitTotal total, {required bool singleDay}) {
  final days = total.days == 1 ? '1 day' : '${total.days} days';
  if (habit?.kind == HabitKind.measurable) {
    final amount = amountLabel(total.total, habit!.unit);
    return singleDay ? amount : '$amount · $days';
  }
  return singleDay ? '✓' : days;
}

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

/// "Thursday, 15 October".
String longDayLabel(DateTime d) =>
    '${weekdayLong(d.weekday)}, ${d.day} ${_months[d.month - 1]}';

/// "15 October 2026".
String fullDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String monthName(int month) => _months[month - 1];

/// Small header text above a period's heading: "Today · Week 42",
/// "Tomorrow", "This week", "Last month"...
String periodKicker(Period p, DateTime today) {
  final now = Period.of(p.kind, today);
  final offset = p == now
      ? 0
      : p == now.next
      ? 1
      : p == now.previous
      ? -1
      : null;
  return switch ((p, offset)) {
    (Day(), 0) => 'Today · Week ${Week.containing(today).week}',
    (Day(), 1) => 'Tomorrow',
    (Day(), -1) => 'Yesterday',
    (Day(:final date), _) => 'Week ${Week.containing(date).week}',
    (Week(), 0) => 'This week',
    (Week(), 1) => 'Next week',
    (Week(), -1) => 'Last week',
    (Week(:final isoYear), _) => '$isoYear',
    (Month(), 0) => 'This month',
    (Month(), 1) => 'Next month',
    (Month(), -1) => 'Last month',
    (Month(:final year), _) => '$year',
  };
}

/// "Thursday", "Week 42", "October".
String periodHeading(Period p) => switch (p) {
  Day(:final date) => weekdayLong(date.weekday),
  Week(:final week) => 'Week $week',
  Month(:final month) => monthName(month),
};

/// "15 October 2026", "12 Oct – 18 Oct", "2026".
String periodSub(Period p) => switch (p) {
  Day(:final date) => fullDate(date),
  Week() =>
    '${dayLabel(p.start).substring(4)} – '
        '${dayLabel(p.endExclusive.subtract(const Duration(hours: 12))).substring(4)}',
  Month(:final year) => '$year',
};

/// A list's short name: "Today", "Tomorrow", "Fri 16 Oct", "Week 42",
/// "October".
String listLabel(Period p, DateTime today) => switch (p) {
  Day() when p == Day(today) => 'Today',
  Day() when p == Day(today).next => 'Tomorrow',
  Day() when p == Day(today).previous => 'Yesterday',
  Day(:final date) => dayLabel(date),
  Week(:final week) => 'Week $week',
  Month(:final month) => monthName(month),
};

/// "Daily", "Weekly", "Monthly", "Mon, Wed", "Monthly · 15".
String repeatShort(RepeatRule rule) => switch (rule.every) {
  RepeatEvery.day => 'Daily',
  RepeatEvery.week => 'Weekly',
  RepeatEvery.weekdays =>
    (rule.weekdays.toList()..sort()).map(weekdayShort).join(', '),
  RepeatEvery.month =>
    rule.dayOfMonth == null ? 'Monthly' : 'Monthly · ${rule.dayOfMonth}',
};

/// "38,400"; decimals kept as they are ("2.5").
String groupThousands(num n) {
  if (n != n.roundToDouble()) return '$n';
  final digits = n.round().abs().toString();
  final out = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}
