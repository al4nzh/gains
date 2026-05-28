package exercisedb

import "testing"

func TestPickBest_BenchPress(t *testing.T) {
	candidates := []Exercise{
		{ExerciseID: "x", Name: "ez bar standing french press", GifURL: "https://example.com/a.gif", Equipments: []string{"ez barbell"}},
		{ExerciseID: "y", Name: "barbell bench press", GifURL: "https://example.com/b.gif", Equipments: []string{"barbell"}},
	}
	got := pickBest("Bench Press", "barbell", candidates)
	if got == nil || got.ExerciseID != "y" {
		t.Fatalf("pickBest() = %#v, want barbell bench press", got)
	}
}

func TestPickBest_SkipsLowScore(t *testing.T) {
	candidates := []Exercise{
		{ExerciseID: "x", Name: "potty squat", GifURL: "https://example.com/a.gif", Equipments: []string{"body weight"}},
	}
	if got := pickBest("Bench Press", "barbell", candidates); got != nil {
		t.Fatalf("pickBest() = %#v, want nil", got)
	}
}

func TestNormalizeName(t *testing.T) {
	if got := normalizeName("  Push-Up  "); got != "push up" {
		t.Fatalf("normalizeName() = %q", got)
	}
}
