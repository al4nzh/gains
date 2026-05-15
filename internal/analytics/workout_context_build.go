package analytics

import "gainsai/internal/workout"

func slimExercisesFromSets(sets []workout.SetOut) []WorkoutContextRecentExercise {
	full := coachWorkoutExerciseSummaries(sets)
	out := make([]WorkoutContextRecentExercise, 0, len(full))
	for _, s := range full {
		out = append(out, WorkoutContextRecentExercise{
			ExerciseID:   s.ExerciseID,
			ExerciseName: s.ExerciseName,
			BestSet:      s.BestSet,
			BestE1RMKg:   s.BestE1RMKg,
		})
	}
	return out
}

func buildWorkoutContextRecentWorkout(row completedWorkoutRow, sets []workout.SetOut) WorkoutContextRecentWorkout {
	snap := snapshotFromRow(row)
	return WorkoutContextRecentWorkout{
		WorkoutID:       snap.WorkoutID,
		CompletedAt:     snap.CompletedAt,
		TotalVolumeKg:   snap.TotalVolumeKg,
		DurationSeconds: snap.DurationSeconds,
		SetCount:        snap.SetCount,
		Exercises:       slimExercisesFromSets(sets),
	}
}
