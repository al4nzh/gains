package aiquota

import (
	"testing"

	"gainsai/internal/config"
)

func TestLimitForUsesConfig(t *testing.T) {
	cfg := &config.Config{
		AIDailyCoachMessages:      200,
		AIDailyWorkoutAnalyses:    50,
		AIDailyRoutineGenerations: 30,
		AIDailyPhysiqueScans:      20,
	}
	s := &Service{cfg: cfg}
	if got := s.limitFor(KindCoachMessage); got != 200 {
		t.Fatalf("coach=%d", got)
	}
	if got := s.limitFor(KindPhysiqueScan); got != 20 {
		t.Fatalf("physique=%d", got)
	}
}
