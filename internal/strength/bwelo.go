package strength

import "strings"

// Estimate1RMBrzycki returns estimated 1RM (kg). Invalid input returns 0.
func Estimate1RMBrzycki(weightKg float64, reps int) float64 {
	if weightKg <= 0 || reps <= 0 {
		return 0
	}
	if reps >= 37 {
		return weightKg
	}
	return weightKg * 36.0 / (37.0 - float64(reps))
}

type BenchmarkLift string

const (
	BenchmarkBenchPress    BenchmarkLift = "bench_press"
	BenchmarkSquat         BenchmarkLift = "squat"
	BenchmarkDeadlift      BenchmarkLift = "deadlift"
	BenchmarkOverheadPress BenchmarkLift = "overhead_press"
	BenchmarkBarbellRow    BenchmarkLift = "barbell_row"
)

// benchmarkRefRatioBW is typical strong-amateur e1RM ÷ bodyweight for that lift.
// Used to normalize across lifts so bench/OHP aren't punished vs deadlift on raw kg/BW alone.
// Values are tunable product constants (not user-specific).
var benchmarkRefRatioBW = map[BenchmarkLift]float64{
	BenchmarkBenchPress:    1.20,
	BenchmarkSquat:         1.75,
	BenchmarkDeadlift:      2.15,
	BenchmarkOverheadPress: 0.70,
	BenchmarkBarbellRow:    1.00,
}

// DistinctBenchmarkFamiliesFromNames counts how many benchmark lift families appear
// in a list of exercise names (duplicates of the same family count once).
func DistinctBenchmarkFamiliesFromNames(names []string) int {
	seen := make(map[BenchmarkLift]struct{})
	for _, name := range names {
		lift, ok := BenchmarkLiftFromExerciseName(name)
		if !ok {
			continue
		}
		seen[lift] = struct{}{}
	}
	return len(seen)
}

// BenchmarkLiftFromExerciseName maps an exercise name to one of the benchmark lifts.
// This is intentionally conservative: only clear canonical names/aliases count.
func BenchmarkLiftFromExerciseName(name string) (BenchmarkLift, bool) {
	n := strings.TrimSpace(strings.ToLower(name))
	switch n {
	case "bench press":
		return BenchmarkBenchPress, true
	case "squat":
		return BenchmarkSquat, true
	case "deadlift":
		return BenchmarkDeadlift, true
	case "ohp", "overhead press":
		return BenchmarkOverheadPress, true
	case "barbell row", "pendlay row":
		return BenchmarkBarbellRow, true
	default:
		return "", false
	}
}

// SessionScoreBW aggregates per-exercise best e1RM in the session, each normalized by bodyweight (kg).
// Each exercise contributes min(bestE1RM/BW, maxRatio) toward the sum (bodyweight-relative strength density).
func SessionScoreBW(bodyweightKg float64, bestE1RMPerExercise map[string]float64, maxRatio float64) float64 {
	if bodyweightKg <= 0 || len(bestE1RMPerExercise) == 0 {
		return 0
	}
	var sum float64
	for _, e1 := range bestE1RMPerExercise {
		if e1 <= 0 {
			continue
		}
		r := e1 / bodyweightKg
		if r > maxRatio {
			r = maxRatio
		}
		sum += r
	}
	return sum
}

// BenchmarkSessionScoreBW computes a session score using only benchmark lifts.
// For each benchmark family, score = min((e1RM/BW) / refBWForLift, maxNorm) where refBWForLift
// is a fixed reference ratio so deadlift/squat don't dominate purely from higher typical kg/BW.
// Session score is the average of those normalized scores across benchmark families present.
//
// maxRawRatio caps raw e1RM/BW before dividing by ref (same role as the old single maxRatio).
// Returns (avgScore, benchmarkCountUsed).
func BenchmarkSessionScoreBW(
	bodyweightKg float64,
	bestE1RMPerExercise map[string]float64,
	namesByExerciseID map[string]string,
	maxRawRatio float64,
) (float64, int) {
	if bodyweightKg <= 0 || len(bestE1RMPerExercise) == 0 || len(namesByExerciseID) == 0 {
		return 0, 0
	}

	bestNormByLift := map[BenchmarkLift]float64{}
	for exID, e1 := range bestE1RMPerExercise {
		if e1 <= 0 {
			continue
		}
		name, ok := namesByExerciseID[exID]
		if !ok {
			continue
		}
		lift, ok := BenchmarkLiftFromExerciseName(name)
		if !ok {
			continue
		}
		norm := BenchmarkNormScore(bodyweightKg, e1, lift, maxRawRatio)
		if norm <= 0 {
			continue
		}
		if cur, exists := bestNormByLift[lift]; !exists || norm > cur {
			bestNormByLift[lift] = norm
		}
	}

	if len(bestNormByLift) == 0 {
		return 0, 0
	}
	var sum float64
	for _, n := range bestNormByLift {
		sum += n
	}
	return sum / float64(len(bestNormByLift)), len(bestNormByLift)
}

// ClampElo keeps rating in a sane band.
func ClampElo(elo int) int {
	if elo < 100 {
		return 100
	}
	if elo > 3600 {
		return 3600
	}
	return elo
}

// RankLabel is a coarse tier for UI.
func RankLabel(elo int) string {
	switch {
	case elo < 820:
		return "iron"
	case elo < 980:
		return "bronze"
	case elo < 1140:
		return "silver"
	case elo < 1320:
		return "gold"
	default:
		return "platinum"
	}
}
