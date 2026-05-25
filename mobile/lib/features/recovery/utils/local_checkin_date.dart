/// Local calendar date helpers for Daily Readiness (not rolling 24h).
class LocalCheckinDate {
  LocalCheckinDate._();

  /// Today as `YYYY-MM-DD` in the device local timezone.
  static String today() {
    final now = DateTime.now();
    return format(now);
  }

  /// `days` ago from now (local), as `YYYY-MM-DD`.
  static String daysAgo(int days) => format(DateTime.now().subtract(Duration(days: days)));

  static String format(DateTime local) {
    final y = local.year;
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// True when local time is before 5:00 AM — do not show readiness prompt.
  static bool isBefore5Am([DateTime? now]) {
    final t = now ?? DateTime.now();
    return t.hour < 5;
  }
}
