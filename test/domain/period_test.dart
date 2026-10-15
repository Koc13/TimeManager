import 'package:time_manager/domain/period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('week keys at ISO year boundaries', () {
    String week(DateTime d) => Week.containing(d).key;

    test(
      'mid-year date',
      () => expect(week(DateTime(2026, 4, 15)), '2026-W16'),
    );
    test('Jan 4 is always week 1', () {
      expect(week(DateTime(2026, 1, 4)), '2026-W01');
      expect(week(DateTime(2020, 1, 4)), '2020-W01');
    });
    test('early January in the previous ISO year (Fri 2016-01-01)', () {
      expect(week(DateTime(2016, 1, 1)), '2015-W53');
    });
    test('late December in the next ISO year (Mon 2018-12-31)', () {
      expect(week(DateTime(2018, 12, 31)), '2019-W01');
    });
    test('53-week year round-trips through start', () {
      const w = Week(2020, 53);
      expect(week(DateTime(2020, 12, 31)), w.key);
      expect(Week.containing(w.start), w);
      expect(w.next.key, '2021-W01');
      expect(const Week(2021, 1).previous.key, '2020-W53');
    });
  });

  test('a week spanning a DST change is 7 days and starts at midnight', () {
    const w = Week(2026, 13); // 2026-03-23..29, EU spring-forward
    expect(w.start, DateTime(2026, 3, 23));
    expect(w.endExclusive, DateTime(2026, 3, 30));
    expect(daysBetween(w.start, w.endExclusive), 7);
  });

  test('months wrap December and handle leap February', () {
    expect(const Month(2026, 12).next.key, '2027-01');
    expect(const Month(2027, 1).previous.key, '2026-12');
    expect(const Month(2024, 2).endExclusive, DateTime(2024, 3, 1));
  });

  test('day next/previous cross month and year ends', () {
    expect(Day(DateTime(2026, 12, 31)).next.key, '2027-01-01');
    expect(Day(DateTime(2024, 3, 1)).previous.key, '2024-02-29');
  });

  test('parse is the inverse of key, and equality is by key', () {
    for (final key in ['2026-10-14', '2026-W42', '2026-10']) {
      expect(Period.parse(key).key, key);
    }
    expect(Period.parse('2026-10-14'), Day(DateTime(2026, 10, 14, 18)));
    expect(Period.tryParse('notes'), isNull);
  });

  test('of() picks the period containing a date', () {
    final d = DateTime(2026, 10, 14, 9);
    expect(Period.of(PeriodKind.day, d).key, '2026-10-14');
    expect(Period.of(PeriodKind.week, d).key, '2026-W42');
    expect(Period.of(PeriodKind.month, d).key, '2026-10');
    expect(Period.of(PeriodKind.week, d).contains(d), isTrue);
  });
}
