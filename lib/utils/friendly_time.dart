/// A moment in the resident's own words: the clock time, and today, tomorrow
/// or the date. Used for "You can send again after 14:32 tomorrow".
///
/// [when] and [now] should both be in local time. "Tomorrow" means the next
/// calendar day, not "within 24 hours".
String describeWhen(DateTime when, DateTime now) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  String two(int value) => value.toString().padLeft(2, '0');

  final time = '${two(when.hour)}:${two(when.minute)}';
  // Compared as calendar dates in UTC, so a clock change does not make a day
  // 23 or 25 hours long.
  final days = DateTime.utc(
    when.year,
    when.month,
    when.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  if (days == 0) return '$time today';
  if (days == 1) return '$time tomorrow';
  return '$time on ${when.day} ${months[when.month - 1]}';
}
