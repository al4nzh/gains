package strength

import "testing"

func TestEloAfter_bench150Then140_bw80(t *testing.T) {
	bw := 80.0
	n150 := BenchmarkNormScore(bw, Estimate1RMBrzycki(150, 5), BenchmarkBenchPress, 6.0)
	n140 := BenchmarkNormScore(bw, Estimate1RMBrzycki(140, 5), BenchmarkBenchPress, 6.0)

	after150 := EloAfterFromBenchmarkSession(n150)
	if after150 <= 1050 {
		t.Fatalf("after150=%d want a strong bench to map well above 1000", after150)
	}

	after140 := EloAfterFromBenchmarkSession(n140)
	if after140 >= after150 {
		t.Fatalf("after140=%d should be below after150=%d", after140, after150)
	}
}

func TestImpliedElo_sameNormSameRating(t *testing.T) {
	a := ImpliedEloFromSessionScore(1.25)
	b := ImpliedEloFromSessionScore(1.25)
	if a != b {
		t.Fatalf("same norm should yield same elo: %d vs %d", a, b)
	}
}
