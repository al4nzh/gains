package gymarchetype

import (
	"testing"
	"time"
)

func TestCalculate_RequiresThreeWorkouts(t *testing.T) {
	got := Calculate(Profile{}, nil, nil, 2)
	if got.Unlocked {
		t.Fatal("expected locked with 2 workouts")
	}
	if got.WorkoutsRequired != 3 {
		t.Fatalf("required=%d", got.WorkoutsRequired)
	}
}

func TestCalculate_BackDayDemon(t *testing.T) {
	now := time.Date(2026, 6, 1, 12, 0, 0, 0, time.UTC)
	workouts := []Workout{
		{ID: "w1", CompletedAt: now.AddDate(0, 0, -6), TotalVolumeKg: 5000, SessionCat: SessionPull},
		{ID: "w2", CompletedAt: now.AddDate(0, 0, -3), TotalVolumeKg: 5200, SessionCat: SessionPull},
		{ID: "w3", CompletedAt: now, TotalVolumeKg: 5100, SessionCat: SessionPull},
	}
	sets := []Set{
		{WorkoutID: "w1", ExerciseName: "Cable Row", MuscleGroup: "back", Reps: 10, WeightKg: 60, VolumeKg: 600},
		{WorkoutID: "w1", ExerciseName: "Lat Pulldown", MuscleGroup: "back", Reps: 10, WeightKg: 50, VolumeKg: 500},
		{WorkoutID: "w2", ExerciseName: "Barbell Row", MuscleGroup: "back", Reps: 8, WeightKg: 80, VolumeKg: 640},
		{WorkoutID: "w2", ExerciseName: "Cable Row", MuscleGroup: "back", Reps: 10, WeightKg: 60, VolumeKg: 600},
		{WorkoutID: "w3", ExerciseName: "Deadlift", MuscleGroup: "back", Reps: 5, WeightKg: 120, VolumeKg: 600},
		{WorkoutID: "w3", ExerciseName: "Face Pull", MuscleGroup: "back", Reps: 15, WeightKg: 20, VolumeKg: 300},
	}
	got := Calculate(Profile{}, workouts, sets, 3)
	if !got.Unlocked {
		t.Fatal("expected unlocked")
	}
	if got.PrimaryArchetype == nil || *got.PrimaryArchetype != BackDayDemon {
		t.Fatalf("primary=%v label=%q", got.PrimaryArchetype, got.PrimaryLabel)
	}
}

func TestCalculate_BenchMerchant(t *testing.T) {
	now := time.Date(2026, 6, 1, 12, 0, 0, 0, time.UTC)
	workouts := []Workout{
		{ID: "w1", CompletedAt: now.AddDate(0, 0, -4), SessionCat: SessionPush},
		{ID: "w2", CompletedAt: now.AddDate(0, 0, -2), SessionCat: SessionPush},
		{ID: "w3", CompletedAt: now, SessionCat: SessionPush},
	}
	sets := []Set{
		{WorkoutID: "w1", ExerciseName: "Bench Press", MuscleGroup: "chest", Reps: 8, WeightKg: 80, VolumeKg: 640},
		{WorkoutID: "w1", ExerciseName: "Incline Bench Press", MuscleGroup: "chest", Reps: 10, WeightKg: 60, VolumeKg: 600},
		{WorkoutID: "w2", ExerciseName: "Bench Press", MuscleGroup: "chest", Reps: 5, WeightKg: 90, VolumeKg: 450},
		{WorkoutID: "w2", ExerciseName: "Cable Fly", MuscleGroup: "chest", Reps: 12, WeightKg: 15, VolumeKg: 180},
		{WorkoutID: "w3", ExerciseName: "Bench Press", MuscleGroup: "chest", Reps: 6, WeightKg: 85, VolumeKg: 510},
		{WorkoutID: "w3", ExerciseName: "Dumbbell Bench Press", MuscleGroup: "chest", Reps: 10, WeightKg: 30, VolumeKg: 300},
	}
	got := Calculate(Profile{}, workouts, sets, 3)
	if got.PrimaryArchetype == nil || *got.PrimaryArchetype != BenchMerchant {
		t.Fatalf("primary=%v (%s)", got.PrimaryArchetype, got.PrimaryLabel)
	}
}

func TestCalculate_PRGoblin(t *testing.T) {
	now := time.Date(2026, 6, 1, 12, 0, 0, 0, time.UTC)
	workouts := []Workout{
		{ID: "w1", CompletedAt: now.AddDate(0, 0, -4), PRCount: 2},
		{ID: "w2", CompletedAt: now.AddDate(0, 0, -2), PRCount: 1},
		{ID: "w3", CompletedAt: now, PRCount: 3},
	}
	sets := []Set{
		{WorkoutID: "w1", ExerciseName: "Squat", MuscleGroup: "legs", Reps: 5, WeightKg: 100, VolumeKg: 500},
		{WorkoutID: "w2", ExerciseName: "Deadlift", MuscleGroup: "back", Reps: 5, WeightKg: 120, VolumeKg: 600},
		{WorkoutID: "w3", ExerciseName: "Bench Press", MuscleGroup: "chest", Reps: 5, WeightKg: 80, VolumeKg: 400},
	}
	got := Calculate(Profile{}, workouts, sets, 3)
	if got.PrimaryArchetype == nil || *got.PrimaryArchetype != PRGoblin {
		t.Fatalf("primary=%v (%s)", got.PrimaryArchetype, got.PrimaryLabel)
	}
}

func TestCalculate_LegDayFugitive(t *testing.T) {
	now := time.Date(2026, 6, 1, 12, 0, 0, 0, time.UTC)
	workouts := []Workout{
		{ID: "w1", CompletedAt: now.AddDate(0, 0, -4), SessionCat: SessionPush},
		{ID: "w2", CompletedAt: now.AddDate(0, 0, -2), SessionCat: SessionUpper},
		{ID: "w3", CompletedAt: now, SessionCat: SessionPush},
	}
	sets := []Set{
		{WorkoutID: "w1", ExerciseName: "OHP", MuscleGroup: "shoulders", Reps: 8, WeightKg: 45, VolumeKg: 360},
		{WorkoutID: "w1", ExerciseName: "Incline Dumbbell Press", MuscleGroup: "chest", Reps: 10, WeightKg: 30, VolumeKg: 300},
		{WorkoutID: "w2", ExerciseName: "Cable Row", MuscleGroup: "back", Reps: 10, WeightKg: 55, VolumeKg: 550},
		{WorkoutID: "w2", ExerciseName: "Lateral Raise", MuscleGroup: "shoulders", Reps: 12, WeightKg: 10, VolumeKg: 120},
		{WorkoutID: "w3", ExerciseName: "Dumbbell Press", MuscleGroup: "chest", Reps: 10, WeightKg: 28, VolumeKg: 280},
		{WorkoutID: "w3", ExerciseName: "Cable Row", MuscleGroup: "back", Reps: 10, WeightKg: 50, VolumeKg: 500},
	}
	got := Calculate(Profile{}, workouts, sets, 3)
	if got.PrimaryArchetype == nil || *got.PrimaryArchetype != LegDayFugitive {
		t.Fatalf("primary=%v (%s)", got.PrimaryArchetype, got.PrimaryLabel)
	}
}

func TestCalculate_ConsistencyDemon(t *testing.T) {
	days := 4
	prof := Profile{TrainingDaysPerWeek: &days}
	now := time.Date(2026, 6, 10, 12, 0, 0, 0, time.UTC)
	workouts := []Workout{
		{ID: "w1", CompletedAt: now.AddDate(0, 0, -6), SessionCat: SessionFull},
		{ID: "w2", CompletedAt: now.AddDate(0, 0, -5), SessionCat: SessionFull},
		{ID: "w3", CompletedAt: now.AddDate(0, 0, -4), SessionCat: SessionFull},
		{ID: "w4", CompletedAt: now.AddDate(0, 0, -3), SessionCat: SessionFull},
		{ID: "w5", CompletedAt: now.AddDate(0, 0, -2), SessionCat: SessionFull},
		{ID: "w6", CompletedAt: now.AddDate(0, 0, -1), SessionCat: SessionFull},
	}
	sets := balancedFullBodySets(workouts)
	got := Calculate(prof, workouts, sets, 6)
	if got.PrimaryArchetype == nil || *got.PrimaryArchetype != ConsistencyDemon {
		t.Fatalf("primary=%v (%s)", got.PrimaryArchetype, got.PrimaryLabel)
	}
}

func balancedFullBodySets(workouts []Workout) []Set {
	var sets []Set
	for _, w := range workouts {
		sets = append(sets,
			Set{WorkoutID: w.ID, ExerciseName: "Squat", MuscleGroup: "legs", Reps: 8, WeightKg: 80, VolumeKg: 640},
			Set{WorkoutID: w.ID, ExerciseName: "Bench Press", MuscleGroup: "chest", Reps: 8, WeightKg: 70, VolumeKg: 560},
			Set{WorkoutID: w.ID, ExerciseName: "Cable Row", MuscleGroup: "back", Reps: 10, WeightKg: 50, VolumeKg: 500},
		)
	}
	return sets
}

func TestComebackScoreFromWorkouts(t *testing.T) {
	now := time.Date(2026, 6, 10, 12, 0, 0, 0, time.UTC)
	workouts := []Workout{
		{CompletedAt: now.AddDate(0, 0, -60)},
		{CompletedAt: now.AddDate(0, 0, -45)},
		{CompletedAt: now.AddDate(0, 0, -5)},
		{CompletedAt: now.AddDate(0, 0, -3)},
		{CompletedAt: now.AddDate(0, 0, -1)},
	}
	score := comebackScoreFromWorkouts(workouts)
	if score <= 0 {
		t.Fatalf("expected positive comeback score, got %v", score)
	}
}
