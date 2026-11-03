import 'package:app/utils/friendly_time.dart';
import 'package:flutter_test/flutter_test.dart';

/// "You can send again after ..." in the resident's own words: a clock time,
/// and today, tomorrow or a date.
void main() {
  final now = DateTime(2026, 11, 3, 17, 5);

  test('later today is the time and "today"', () {
    expect(describeWhen(DateTime(2026, 11, 3, 23, 40), now), '23:40 today');
  });

  test(
    'the next calendar day is "tomorrow", with the time padded to two digits',
    () {
      expect(describeWhen(DateTime(2026, 11, 4, 9, 5), now), '09:05 tomorrow');
      // Just past midnight is still "tomorrow", though under a day away.
      expect(describeWhen(DateTime(2026, 11, 4, 0, 10), now), '00:10 tomorrow');
    },
  );

  test('anything further off is a date', () {
    expect(describeWhen(DateTime(2026, 11, 5, 14, 32), now), '14:32 on 5 Nov');
    expect(describeWhen(DateTime(2026, 12, 25, 8, 0), now), '08:00 on 25 Dec');
  });

  test('"tomorrow" is the next calendar day across a month end', () {
    expect(
      describeWhen(DateTime(2026, 12, 1, 6, 30), DateTime(2026, 11, 30, 20, 0)),
      '06:30 tomorrow',
    );
  });
}
