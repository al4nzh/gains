package strength

import "math"

// BenchmarkLiftComparison is one benchmark family's performance vs the user's history.
type BenchmarkLiftComparison struct {
	Lift          BenchmarkLift
	CurrentNorm   float64
	PriorBestNorm float64 // 0 when the user has no prior countable set for this family
}

// BenchmarkLiftComparisons builds per-family current vs historical-best norms for this finish.
func BenchmarkLiftComparisons(
	bodyweightKg float64,
	bestE1RMThis map[string]float64,
	namesThis map[string]string,
	histE1 map[string]float64,
	histNames map[string]string,
	maxRawRatio float64,
) []BenchmarkLiftComparison {
	bestNormThis := map[BenchmarkLift]float64{}
	for exID, e1 := range bestE1RMThis {
		name, ok := namesThis[exID]
		if !ok {
			continue
		}
		lift, ok := BenchmarkLiftFromExerciseName(name)
		if !ok {
			continue
		}
		n := BenchmarkNormScore(bodyweightKg, e1, lift, maxRawRatio)
		if n > bestNormThis[lift] {
			bestNormThis[lift] = n
		}
	}

	bestNormHist := map[BenchmarkLift]float64{}
	for exID, e1 := range histE1 {
		name, ok := histNames[exID]
		if !ok {
			continue
		}
		lift, ok := BenchmarkLiftFromExerciseName(name)
		if !ok {
			continue
		}
		n := BenchmarkNormScore(bodyweightKg, e1, lift, maxRawRatio)
		if n > bestNormHist[lift] {
			bestNormHist[lift] = n
		}
	}

	out := make([]BenchmarkLiftComparison, 0, len(bestNormThis))
	for lift, cur := range bestNormThis {
		out = append(out, BenchmarkLiftComparison{
			Lift:          lift,
			CurrentNorm:   cur,
			PriorBestNorm: bestNormHist[lift],
		})
	}
	return out
}

// BenchmarkNormScore is (e1RM/BW)/reference for a lift, with only a raw kg/BW safety cap.
func BenchmarkNormScore(bodyweightKg, e1RMKg float64, lift BenchmarkLift, maxRawRatio float64) float64 {
	ref, ok := benchmarkRefRatioBW[lift]
	if !ok || ref <= 0 || bodyweightKg <= 0 || e1RMKg <= 0 {
		return 0
	}
	r := e1RMKg / bodyweightKg
	if maxRawRatio > 0 && r > maxRawRatio {
		r = maxRawRatio
	}
	return r / ref
}

// ParBenchmarkNormForElo is the normalized strength par for a rating (1.0 ≈ average at 1000).
func ParBenchmarkNormForElo(elo int) float64 {
	par := 1.0 + float64(elo-1000)*0.00022
	if par < 0.88 {
		return 0.88
	}
	if par > 1.22 {
		return 1.22
	}
	return par
}

// ImpliedEloFromSessionScore maps average benchmark norm to a strength rating.
// Norm 1.0 ≈ 1000 (intermediate reference); stronger sessions imply higher ratings.
func ImpliedEloFromSessionScore(sessionScore float64) int {
	return ClampElo(int(math.Round(1000 + 280*(sessionScore-1.0))))
}

// EloAfterFromBenchmarkNorms sets strength rating from lifetime-best norms per benchmark family
// (average across families). A single-lift day does not reset Elo to only that lift.
func EloAfterFromBenchmarkNorms(normsByLift map[BenchmarkLift]float64) int {
	avg, _ := AverageBenchmarkNorms(normsByLift)
	return ImpliedEloFromSessionScore(avg)
}
