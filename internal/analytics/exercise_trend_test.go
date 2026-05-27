package analytics

import "testing"

func TestTrendFromSessionE1RMs_smoothedUp(t *testing.T) {
	// Noisy last session but recent half still above prior half.
	series := []float64{80, 82, 84, 83, 86, 88}
	got := trendFromSessionE1RMs(series, "")
	if got != "up" {
		t.Fatalf("got %q want up", got)
	}
}

func TestTrendFromSessionE1RMs_lastDipStillUp(t *testing.T) {
	series := []float64{70, 72, 74, 76, 78, 76}
	got := trendFromSessionE1RMs(series, "")
	if got != "up" {
		t.Fatalf("got %q want up (recent avg > prior avg)", got)
	}
}

func TestTrendFromSessionE1RMs_twoSessionsUsesPair(t *testing.T) {
	if trendFromSessionE1RMs([]float64{100, 100.4}, "") != "flat" {
		t.Fatal("small change should be flat")
	}
	if trendFromSessionE1RMs([]float64{100, 102}, "") != "up" {
		t.Fatal("want up")
	}
}

func TestTrendFromSessionE1RMs_singleSession(t *testing.T) {
	if trendFromSessionE1RMs([]float64{100}, "single_session") != "single_session" {
		t.Fatal("detail single label")
	}
	if trendFromSessionE1RMs([]float64{100}, "") != "flat" {
		t.Fatal("list single session")
	}
}
