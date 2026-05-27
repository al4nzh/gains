package strength

import "testing"

func TestImpliedElo_sameNormSameRating(t *testing.T) {
	a := ImpliedEloFromSessionScore(1.25)
	b := ImpliedEloFromSessionScore(1.25)
	if a != b {
		t.Fatalf("same norm should yield same elo: %d vs %d", a, b)
	}
}
