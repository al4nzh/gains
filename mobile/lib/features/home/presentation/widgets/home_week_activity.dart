import 'package:gains/features/recovery/utils/local_checkin_date.dart';
import 'package:gains/features/workouts/models/workout.dart';

/// Last 7 **local** calendar days (oldest → newest), whether each had a completed workout.
List<bool> weekTrainingDaysFromWorkouts(List<Workout> workouts) {
  final now = DateTime.now();
  final days = List.generate(7, (i) {
    final d = now.subtract(Duration(days: 6 - i));
    return DateTime(d.year, d.month, d.day);
  });

  final trained = <String>{};
  for (final w in workouts) {
    final completed = w.completedAt;
    if (completed == null) continue;
    final local = completed.toLocal();
    trained.add(LocalCheckinDate.format(local));
  }

  return days.map((d) => trained.contains(LocalCheckinDate.format(d))).toList();
}

/// Consecutive local-day workout streak. Only active if the last workout was today or yesterday.
int workoutStreakDaysFromWorkouts(List<Workout> workouts) {
  final trainedDates = <String>{};
  for (final w in workouts) {
    final completed = w.completedAt;
    if (completed == null) continue;
    trainedDates.add(LocalCheckinDate.format(completed.toLocal()));
  }
  if (trainedDates.isEmpty) return 0;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final todayKey = LocalCheckinDate.format(today);
  final yesterdayKey = LocalCheckinDate.format(today.subtract(const Duration(days: 1)));

  if (!trainedDates.contains(todayKey) && !trainedDates.contains(yesterdayKey)) {
    return 0;
  }

  var cursor = trainedDates.contains(todayKey) ? today : today.subtract(const Duration(days: 1));
  var streak = 0;
  while (trainedDates.contains(LocalCheckinDate.format(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// Single-letter weekday for a local calendar day.
String weekdayLetter(DateTime localDay) {
  const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  return letters[localDay.weekday - 1];
}

/// Local calendar days for the last 7 days (oldest → newest).
List<DateTime> lastSevenLocalDays() {
  final now = DateTime.now();
  return List.generate(7, (i) {
    final d = now.subtract(Duration(days: 6 - i));
    return DateTime(d.year, d.month, d.day);
  });
}
