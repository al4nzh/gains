package adaptiverecommendations

import "testing"

func TestBuildRecommendations_lowSharpnessReducesAccessory(t *testing.T) {
	in := evalInput{
		SharpnessScore: 52,
		HasSharpness:   true,
		RoutineExercises: []routineExerciseEval{
			{RoutineExerciseID: "re1", ExerciseID: "e1", ExerciseName: "Bench Press", MuscleGroup: "chest", TargetSets: intPtr(4), IsAccessory: false},
			{RoutineExerciseID: "re2", ExerciseID: "e2", ExerciseName: "Cable Fly", MuscleGroup: "chest", TargetSets: intPtr(3), IsAccessory: true},
		},
		ExerciseMeta: map[string]exerciseMeta{},
	}
	recs := buildRecommendations(in, "routine")
	found := false
	for _, r := range recs {
		if r.Type == TypeReduceVolume && r.TargetExerciseID != nil && *r.TargetExerciseID == "e2" {
			found = true
			if r.SuggestedChange.SetsDelta == nil || *r.SuggestedChange.SetsDelta != -1 {
				t.Fatalf("expected sets_delta -1, got %+v", r.SuggestedChange)
			}
		}
	}
	if !found {
		t.Fatal("expected reduce_volume for accessory")
	}
}

func TestBuildRecommendations_shoulderSwap(t *testing.T) {
	in := evalInput{
		InjuryText: "shoulder pain on pressing",
		RoutineExercises: []routineExerciseEval{
			{RoutineExerciseID: "re1", ExerciseID: "e1", ExerciseName: "Bench Press", MuscleGroup: "chest"},
		},
		ExerciseMeta: map[string]exerciseMeta{
			"alt": {ID: "alt", Name: "Dumbbell Bench Press", MuscleGroup: "chest"},
		},
	}
	recs := buildRecommendations(in, "exercise")
	found := false
	for _, r := range recs {
		if r.Type == TypeSwapExercise {
			found = true
		}
	}
	if !found {
		t.Fatal("expected swap recommendation")
	}
}

func TestBuildRecommendations_increaseWeightUsesLastSessionLoad(t *testing.T) {
	in := evalInput{
		SharpnessScore: 80,
		HasSharpness:   true,
		ExerciseTrends: map[string]string{"bench": "up"},
		LastBestLoad: map[string]lastSetLoadEval{
			"bench": {Reps: 5, WeightKg: 100},
		},
		RoutineExercises: []routineExerciseEval{
			{RoutineExerciseID: "re1", ExerciseID: "bench", ExerciseName: "Bench Press", MuscleGroup: "chest"},
		},
		ExerciseMeta: map[string]exerciseMeta{"bench": {ID: "bench", Name: "Bench Press"}},
	}
	recs := buildRecommendations(in, "routine")
	found := false
	for _, r := range recs {
		if r.Type == TypeIncreaseWeight {
			found = true
			if r.SuggestedChange.WeightDeltaKg == nil || *r.SuggestedChange.WeightDeltaKg != 2.5 {
				t.Fatalf("expected +2.5 kg delta, got %+v", r.SuggestedChange)
			}
		}
	}
	if !found {
		t.Fatal("expected increase_weight without routine target_weight_kg")
	}
}

func TestBuildRecommendations_reduceIntensityOnlyInRoutine(t *testing.T) {
	in := evalInput{
		ExerciseTrends:       map[string]string{"bench": "down", "row": "down"},
		ExerciseSessionCount: map[string]int{"bench": 4, "row": 4},
		ExerciseMeta: map[string]exerciseMeta{
			"bench": {ID: "bench", Name: "Bench Press"},
			"row":   {ID: "row", Name: "Barbell Row"},
		},
		RoutineExercises: []routineExerciseEval{
			{RoutineExerciseID: "re-row", ExerciseID: "row", ExerciseName: "Barbell Row", MuscleGroup: "back"},
		},
	}
	recs := buildRecommendations(in, "routine")
	for _, r := range recs {
		if r.Type == TypeReduceIntensity && r.TargetExerciseID != nil && *r.TargetExerciseID == "bench" {
			t.Fatal("should not recommend bench intensity on back-only routine")
		}
	}
	foundRow := false
	for _, r := range recs {
		if r.Type == TypeReduceIntensity && r.TargetExerciseID != nil && *r.TargetExerciseID == "row" {
			foundRow = true
		}
	}
	if !foundRow {
		t.Fatal("expected reduce_intensity for row in routine")
	}
}

func intPtr(v int) *int { return &v }
