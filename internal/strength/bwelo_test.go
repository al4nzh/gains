package strength

import (
	"math"
	"testing"
)

// Same multiple of reference e1RM/BW for bench vs deadlift → same normalized contribution.
func TestDistinctBenchmarkFamiliesFromNames(t *testing.T) {
	n := DistinctBenchmarkFamiliesFromNames([]string{
		"Bench Press", "Incline Bench Press", "Squat", "bench press",
	})
	if n != 2 {
		t.Fatalf("families=%d want 2 (bench + squat)", n)
	}
}

func TestBenchmarkSessionScoreBW_perLiftNormalization(t *testing.T) {
	bw := 100.0
	names := map[string]string{
		"b-id": "Bench Press",
		"d-id": "Deadlift",
	}
	// Both exactly at reference ratio for their lift
	best := map[string]float64{
		"b-id": 1.20 * bw, // 1.2×BW bench
		"d-id": 2.15 * bw, // 2.15×BW deadlift
	}
	s, n := BenchmarkSessionScoreBW(bw, best, names, 6.0)
	if n != 2 {
		t.Fatalf("benchmarkCount=%d want 2", n)
	}
	if math.Abs(s-1.0) > 1e-6 {
		t.Fatalf("session score=%v want 1.0 (equal ref-relative strength)", s)
	}
}
