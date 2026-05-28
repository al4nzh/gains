package analytics

import (
	"gainsai/internal/profile"
	"gainsai/internal/recovery"
)

// ExerciseTrendAgg is per-exercise progression used by adaptive recommendations.
type ExerciseTrendAgg struct {
	Trend string
	Hist  []float64
}

// LastSetLoad is the best set (reps × weight) from the exercise's most recent routine session.
type LastSetLoad struct {
	Reps     int
	WeightKg float64
}

// LastBestSetLoadPerExercise returns per-exercise best set load from the latest completed
// workout in rows (routine-scoped rows expected from the caller).
func LastBestSetLoadPerExercise(rows []ProgressionSetRow) map[string]LastSetLoad {
	m := aggregateExerciseHistories(rows)
	out := make(map[string]LastSetLoad)
	for exID, a := range m {
		if len(a.hist) == 0 {
			continue
		}
		lastWID := a.hist[len(a.hist)-1].workoutID
		best := bestSetLoadForWorkoutExercise(rows, lastWID, exID)
		if best == nil || best.Reps == nil || best.WeightKg == nil {
			continue
		}
		out[exID] = LastSetLoad{Reps: *best.Reps, WeightKg: *best.WeightKg}
	}
	return out
}

// SharpnessFromCheckinsForAdaptive exposes the home sharpness scorer for rule engines.
func SharpnessFromCheckinsForAdaptive(checkins []recovery.Checkin, prof *profile.Profile) *SharpnessOverview {
	return sharpnessFromCheckins(checkins, prof)
}

// AggregateExerciseHistoriesForAdaptive returns trend labels per exercise_id from progression rows.
func AggregateExerciseHistoriesForAdaptive(rows []ProgressionSetRow) map[string]ExerciseTrendAgg {
	m := aggregateExerciseHistories(rows)
	out := make(map[string]ExerciseTrendAgg, len(m))
	for id, a := range m {
		series := make([]float64, len(a.hist))
		for i := range a.hist {
			series[i] = a.hist[i].e1
		}
		out[id] = ExerciseTrendAgg{
			Trend: trendFromSessionE1RMs(series, ""),
			Hist:  series,
		}
	}
	return out
}
