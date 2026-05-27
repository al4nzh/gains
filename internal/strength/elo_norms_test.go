package strength

import "testing"

// Historical bench + dead PRs; today's session only has a weak deadlift attempt.
func TestEloLifetimeNorms_weakDeadliftDayStable(t *testing.T) {
	bw := 80.0
	benchE1 := Estimate1RMBrzycki(150, 5)
	deadStrong := Estimate1RMBrzycki(180, 5)
	deadWeak := Estimate1RMBrzycki(100, 5)

	names := map[string]string{
		"b":      "Bench Press",
		"d-hist": "Deadlift",
		"d-new":  "Deadlift",
	}
	merged := map[string]float64{
		"b":      benchE1,
		"d-hist": deadStrong,
		"d-new":  deadWeak,
	}
	norms := BestBenchmarkNormsByFamily(bw, merged, names, 6.0)
	elo := EloAfterFromBenchmarkNorms(norms)

	if norms[BenchmarkDeadlift] < BenchmarkNormScore(bw, deadStrong, BenchmarkDeadlift, 6.0)-0.01 {
		t.Fatal("deadlift family should keep stronger lifetime norm")
	}
	if elo < 1000 {
		t.Fatalf("elo=%d expected stable composite rating", elo)
	}
}

func TestMergedE1RM_keepsHistoricalMax(t *testing.T) {
	merged := map[string]float64{"a": 100}
	bestThis := map[string]float64{"a": 80}
	for id, e1 := range bestThis {
		if e1 > merged[id] {
			merged[id] = e1
		}
	}
	if merged["a"] != 100 {
		t.Fatal("weaker session must not reduce historical exercise best")
	}
}
