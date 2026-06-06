package analytics

import (
	"strings"
	"testing"
	"time"

	"gainsai/internal/routine"
	"gainsai/internal/workout"
)

func TestClassifyRoutineName(t *testing.T) {
	tests := []struct {
		name string
		want sessionCategory
	}{
		{"Push Day", catPush},
		{"Pull Day", catPull},
		{"Legs", catLegs},
		{"Upper Body A", catUpper},
		{"Lower Body B", catLower},
		{"Strength 5×5", catFull},
	}
	for _, tt := range tests {
		if got := classifyRoutineName(tt.name); got != tt.want {
			t.Fatalf("%q: got %q want %q", tt.name, got, tt.want)
		}
	}
}

func TestBuildTrainToday_PicksPullAfterLegs(t *testing.T) {
	now := time.Date(2026, 6, 3, 10, 0, 0, 0, time.UTC)
	legsID := "r-legs"
	pushID := "r-push"
	pullID := "r-pull"
	routines := []routine.Routine{
		{ID: pushID, Name: "Push Day"},
		{ID: pullID, Name: "Pull Day"},
		{ID: legsID, Name: "Legs"},
	}
	legsName := "Legs"
	recent := []completedWorkoutRow{
		{
			ID:          "w1",
			CompletedAt: now.Add(-20 * time.Hour),
			RoutineID:   &legsID,
			Name:        &legsName,
		},
	}
	out := buildTrainToday(now, &SharpnessOverview{Score: 82}, nil, routines, recent)
	if out == nil {
		t.Fatal("nil recommendation")
	}
	if out.Action != "start_routine" {
		t.Fatalf("action=%q", out.Action)
	}
	if out.RoutineID == nil || *out.RoutineID != pullID {
		t.Fatalf("routine=%v want pull", out.RoutineID)
	}
	foundRecovered := false
	foundLegsWait := false
	for _, r := range out.Reasons {
		if r == "Back and biceps are recovered" {
			foundRecovered = true
		}
		if strings.Contains(r, "Legs") && strings.Contains(r, "recover") {
			foundLegsWait = true
		}
	}
	if !foundRecovered {
		t.Fatalf("missing recovered reason: %v", out.Reasons)
	}
	if !foundLegsWait {
		t.Fatalf("missing legs wait reason: %v", out.Reasons)
	}
}

func TestBuildTrainToday_ResumeActive(t *testing.T) {
	now := time.Now().UTC()
	wid := "w-active"
	rid := "r-push"
	name := "Push Day"
	active := &workout.Workout{
		ID:        wid,
		RoutineID: &rid,
		Name:      &name,
	}
	routines := []routine.Routine{{ID: rid, Name: "Push Day"}}
	out := buildTrainToday(now, &SharpnessOverview{Score: 70}, active, routines, nil)
	if out.Action != "resume_workout" {
		t.Fatalf("action=%q", out.Action)
	}
	if out.WorkoutID == nil || *out.WorkoutID != wid {
		t.Fatalf("workout id=%v", out.WorkoutID)
	}
}
