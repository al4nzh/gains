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
