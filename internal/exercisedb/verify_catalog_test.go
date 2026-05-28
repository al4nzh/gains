package exercisedb

import (
	"context"
	"os"
	"strings"
	"testing"
	"time"
)

// gainsCatalog is the system seed list (name, equipment) from migrations/000004_seed_exercises.up.sql
var gainsCatalog = []struct {
	Name      string
	Equipment string
}{
	{"Bench Press", "barbell"},
	{"Incline Bench Press", "barbell"},
	{"Incline DB Press", "dumbbell"},
	{"Dumbbell Bench Press", "dumbbell"},
	{"Cable Fly", "cable"},
	{"Push Up", "bodyweight"},
	{"Dip", "bodyweight"},
	{"Squat", "barbell"},
	{"Front Squat", "barbell"},
	{"Leg Press", "machine"},
	{"Romanian Deadlift", "barbell"},
	{"Leg Curl", "machine"},
	{"Leg Extension", "machine"},
	{"Walking Lunge", "dumbbell"},
	{"Bulgarian Split Squat", "dumbbell"},
	{"Hip Thrust", "barbell"},
	{"Calf Raise", "machine"},
	{"Deadlift", "barbell"},
	{"Sumo Deadlift", "barbell"},
	{"Pull Up", "bodyweight"},
	{"Chin Up", "bodyweight"},
	{"Lat Pulldown", "machine"},
	{"Barbell Row", "barbell"},
	{"Pendlay Row", "barbell"},
	{"Dumbbell Row", "dumbbell"},
	{"Cable Row", "cable"},
	{"T-Bar Row", "machine"},
	{"Face Pull", "cable"},
	{"OHP", "barbell"},
	{"Dumbbell Shoulder Press", "dumbbell"},
	{"Lateral Raise", "dumbbell"},
	{"Front Raise", "dumbbell"},
	{"Rear Delt Fly", "dumbbell"},
	{"Arnold Press", "dumbbell"},
	{"Curls", "dumbbell"},
	{"Barbell Curl", "barbell"},
	{"Hammer Curl", "dumbbell"},
	{"Preacher Curl", "machine"},
	{"Triceps Pushdown", "cable"},
	{"Skull Crusher", "barbell"},
	{"Overhead Triceps Extension", "dumbbell"},
	{"Close Grip Bench Press", "barbell"},
	{"Plank", "bodyweight"},
	{"Hanging Leg Raise", "bodyweight"},
	{"Cable Crunch", "cable"},
	{"Farmer Carry", "dumbbell"},
	{"Kettlebell Swing", "kettlebell"},
}

// TestVerifyGainsCatalogAgainstExerciseDB hits the live OSS API. Skip with: go test -short
func TestVerifyGainsCatalogAgainstExerciseDB(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping live ExerciseDB verification in -short mode")
	}
	if os.Getenv("VERIFY_EXERCISEDB") != "1" {
		t.Skip("set VERIFY_EXERCISEDB=1 to run live catalog GIF verification")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()

	svc := NewService(NewClient(""), true)
	var missing, weak []string
	seenGIF := make(map[string][]string)

	for _, ex := range gainsCatalog {
		url, err := svc.resolve(ctx, ex.Name, ex.Equipment)
		if err != nil || url == "" {
			missing = append(missing, ex.Name)
			continue
		}
		seenGIF[url] = append(seenGIF[url], ex.Name)
		// Flag suspiciously short token-only matches logged via pick debug - optional
		if strings.Contains(url, "potty") {
			weak = append(weak, ex.Name+" -> "+url)
		}
	}

	for url, names := range seenGIF {
		if len(names) > 1 {
			t.Logf("shared gif (%d exercises): %v -> %s", len(names), names, url)
		}
	}
	if len(weak) > 0 {
		t.Errorf("weak matches: %v", weak)
	}
	if len(missing) > 0 {
		t.Errorf("no gif for %d catalog exercises: %v", len(missing), missing)
	}
}
