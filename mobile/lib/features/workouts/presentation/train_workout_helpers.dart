import 'package:gains/core/units/body_units.dart';
import 'package:gains/features/home/presentation/widgets/home_formatters.dart';
import 'package:gains/features/recovery/utils/local_checkin_date.dart';
import 'package:gains/features/workouts/models/workout.dart';

class WorkoutDateSection {
  const WorkoutDateSection({
    required this.header,
    required this.dateKey,
    required this.workouts,
  });

  final String header;
  final String dateKey;
  final List<Workout> workouts;
}

bool workoutHadPr(Workout workout) {
  final prs = workout.finishStats?.prs;
  return prs != null && prs.isNotEmpty;
}

List<String> muscleGroupsForWorkout(Workout workout, Map<String, String> exerciseMuscleGroup) {
  final exerciseIds = <String>{};
  final stats = workout.finishStats;
  if (stats != null) {
    for (final e in stats.e1rmByExercise) {
      exerciseIds.add(e.exerciseId);
    }
  }
  if (exerciseIds.isEmpty) {
    for (final s in workout.sets) {
      exerciseIds.add(s.exerciseId);
    }
  }

  final groups = <String>{};
  for (final id in exerciseIds) {
    final raw = exerciseMuscleGroup[id];
    if (raw == null || raw.isEmpty) continue;
    groups.add(humanizeSnake(raw));
  }
  final list = groups.toList()..sort();
  return list;
}

List<WorkoutDateSection> groupCompletedWorkoutsByDate(List<Workout> completed) {
  final sorted = [...completed]..sort((a, b) {
      final ac = a.completedAt ?? a.startedAt;
      final bc = b.completedAt ?? b.startedAt;
      return bc.compareTo(ac);
    });

  final byDate = <String, List<Workout>>{};
  final order = <String>[];

  for (final w in sorted) {
    final dt = (w.completedAt ?? w.startedAt).toLocal();
    final key = LocalCheckinDate.format(DateTime(dt.year, dt.month, dt.day));
    if (!byDate.containsKey(key)) {
      byDate[key] = [];
      order.add(key);
    }
    byDate[key]!.add(w);
  }

  return order
      .map(
        (key) => WorkoutDateSection(
          header: sectionHeaderForDateKey(key),
          dateKey: key,
          workouts: byDate[key]!,
        ),
      )
      .toList();
}

String sectionHeaderForDateKey(String yyyyMmDd) {
  final today = LocalCheckinDate.today();
  if (yyyyMmDd == today) return 'Today';
  if (yyyyMmDd == LocalCheckinDate.daysAgo(1)) return 'Yesterday';

  final parts = yyyyMmDd.split('-');
  if (parts.length != 3) return yyyyMmDd;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return yyyyMmDd;

  const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
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
  final dt = DateTime(y, m, d);
  final now = DateTime.now();
  if (dt.year == now.year) {
    return '${weekdays[dt.weekday - 1]}, ${months[m - 1]} $d';
  }
  return '${months[m - 1]} $d, $y';
}

String workoutSessionSubtitle(Workout w, BodyUnitSystem units) {
  final vol = w.totalVolumeKg != null ? formatVolumeKg(w.totalVolumeKg!, units) : null;
  final dur = w.durationSeconds != null ? formatDuration(w.durationSeconds!) : null;
  final parts = <String>[];
  if (vol != null) parts.add(vol);
  if (dur != null) parts.add(dur);
  final sets = w.finishStats?.setCount ?? w.sets.length;
  if (sets > 0) parts.add('$sets sets');
  return parts.isEmpty ? 'Completed' : parts.join(' · ');
}
