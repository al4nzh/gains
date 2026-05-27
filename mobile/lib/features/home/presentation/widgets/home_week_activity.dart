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
