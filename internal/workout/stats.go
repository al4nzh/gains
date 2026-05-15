package workout

import (
	"gainsai/internal/strength"
)

// BestE1RMPerExerciseFromSets returns max Brzycki e1RM per exercise_id for the given sets.
func BestE1RMPerExerciseFromSets(sets []Set) map[string]float64 {
	out := make(map[string]float64)
	for _, s := range sets {
		if s.Reps == nil || s.WeightKg == nil || *s.Reps <= 0 || *s.WeightKg <= 0 {
			continue
		}
		e := strength.Estimate1RMBrzycki(*s.WeightKg, *s.Reps)
		if e <= 0 {
			continue
		}
		if e > out[s.ExerciseID] {
			out[s.ExerciseID] = e
		}
	}
	return out
}
