package ai

import (
	"context"
	"encoding/json"
	"strings"

	"gainsai/internal/actionengine"
	"gainsai/internal/profile"
	"gainsai/internal/routine"
)

type ActionApplier struct {
	profiles *profile.Repository
	routines *routine.Service
}

func NewActionApplier(profiles *profile.Repository, routines *routine.Service) *ActionApplier {
	return &ActionApplier{profiles: profiles, routines: routines}
}

func (a *ActionApplier) Apply(ctx context.Context, userID string, va *validatedAction) error {
	switch va.ActionType {
	case actionengine.ActionUpdateGoal:
		return a.applyUpdateGoal(ctx, userID, va.Payload)
	case actionengine.ActionUpdateInjuryNotes:
		return a.applyUpdateInjuryNotes(ctx, userID, va.Payload)
	case actionengine.ActionUpdateBodyweight:
		return a.applyUpdateBodyweight(ctx, userID, va.Payload)
	case actionengine.ActionUpdateHeight:
		return a.applyUpdateHeight(ctx, userID, va.Payload)
	case actionengine.ActionAddExerciseToRoutine:
		return a.applyAddExercise(ctx, userID, va.Payload)
	case actionengine.ActionRemoveExerciseFromRoutine:
		return a.applyRemoveExercise(ctx, userID, va.TargetID, va.Payload)
	case actionengine.ActionReplaceExerciseInRoutine:
		return a.applyReplaceExercise(ctx, userID, va.TargetID, va.Payload)
	case actionengine.ActionUpdateRoutineExerciseSets:
		return a.applyUpdateSets(ctx, userID, va.TargetID, va.Payload)
	case actionengine.ActionUpdateRoutineExerciseRepRange:
		return a.applyUpdateRepRange(ctx, userID, va.TargetID, va.Payload)
	case actionengine.ActionUpdateRoutineExerciseRest:
		return a.applyUpdateRest(ctx, userID, va.TargetID, va.Payload)
	case actionengine.ActionRenameRoutine:
		return a.applyRenameRoutine(ctx, userID, va.TargetID, va.Payload)
	default:
		return ErrUnsupportedAction
	}
}

func (a *ActionApplier) applyUpdateGoal(ctx context.Context, userID string, payload []byte) error {
	var body struct {
		Goal string `json:"goal"`
	}
	if err := json.Unmarshal(payload, &body); err != nil {
		return err
	}
	prof, err := a.profiles.GetByUserID(ctx, userID)
	if err != nil {
		return err
	}
	g := strings.TrimSpace(body.Goal)
	prof.FitnessGoal = &g
	return a.profiles.Upsert(ctx, prof)
}

func (a *ActionApplier) applyUpdateInjuryNotes(ctx context.Context, userID string, payload []byte) error {
	var body struct {
		InjuryNotes *string `json:"injury_notes"`
	}
	if err := json.Unmarshal(payload, &body); err != nil {
		return err
	}
	prof, err := a.profiles.GetByUserID(ctx, userID)
	if err != nil {
		return err
	}
	prof.InjuryNotes = body.InjuryNotes
	return a.profiles.Upsert(ctx, prof)
}

func (a *ActionApplier) applyUpdateBodyweight(ctx context.Context, userID string, payload []byte) error {
	var body struct {
		WeightKg float64 `json:"weight_kg"`
	}
	if err := json.Unmarshal(payload, &body); err != nil {
		return err
	}
	prof, err := a.profiles.GetByUserID(ctx, userID)
	if err != nil {
		return err
	}
	prof.WeightKg = &body.WeightKg
	return a.profiles.Upsert(ctx, prof)
}

func (a *ActionApplier) applyUpdateHeight(ctx context.Context, userID string, payload []byte) error {
	var body struct {
		HeightCm float64 `json:"height_cm"`
	}
	if err := json.Unmarshal(payload, &body); err != nil {
		return err
	}
	prof, err := a.profiles.GetByUserID(ctx, userID)
	if err != nil {
		return err
	}
	prof.HeightCm = &body.HeightCm
	return a.profiles.Upsert(ctx, prof)
}

func (a *ActionApplier) applyAddExercise(ctx context.Context, userID string, payload []byte) error {
	var body struct {
		RoutineID    string  `json:"routine_id"`
		ExerciseID   string  `json:"exercise_id"`
		TargetSets   *int    `json:"target_sets"`
		TargetRepMin *int    `json:"target_rep_min"`
		TargetRepMax *int    `json:"target_rep_max"`
		RestSeconds  *int    `json:"rest_seconds"`
		Position     *int    `json:"position"`
	}
	if err := json.Unmarshal(payload, &body); err != nil {
		return err
	}
	_, err := a.routines.AddRoutineExercise(ctx, userID, body.RoutineID, routine.AddRoutineExerciseInput{
		ExerciseID:   body.ExerciseID,
		TargetSets:   body.TargetSets,
		TargetRepMin: body.TargetRepMin,
		TargetRepMax: body.TargetRepMax,
		RestSeconds:  body.RestSeconds,
		Position:     body.Position,
	})
	return err
}

func (a *ActionApplier) applyRemoveExercise(ctx context.Context, userID string, targetID *string, payload []byte) error {
	var body struct {
		RoutineID string `json:"routine_id"`
	}
	if err := json.Unmarshal(payload, &body); err != nil {
		return err
	}
	rowID := stringPtrVal(targetID)
	return a.routines.DeleteRoutineExercise(ctx, userID, body.RoutineID, rowID)
}

func (a *ActionApplier) applyReplaceExercise(ctx context.Context, userID string, targetID *string, payload []byte) error {
	var body struct {
		RoutineID     string `json:"routine_id"`
		NewExerciseID string `json:"new_exercise_id"`
	}
	if err := json.Unmarshal(payload, &body); err != nil {
		return err
	}
	rowID := stringPtrVal(targetID)
	_, err := a.routines.ReplaceRoutineExercise(ctx, userID, body.RoutineID, rowID, body.NewExerciseID)
	return err
}

func (a *ActionApplier) applyUpdateSets(ctx context.Context, userID string, targetID *string, payload []byte) error {
	var body struct {
		RoutineID  string `json:"routine_id"`
		TargetSets int    `json:"target_sets"`
	}
	if err := json.Unmarshal(payload, &body); err != nil {
		return err
	}
	sets := body.TargetSets
	_, err := a.routines.UpdateRoutineExercise(ctx, userID, body.RoutineID, stringPtrVal(targetID), routine.UpdateRoutineExerciseInput{
		TargetSets: &sets,
	})
	return err
}

func (a *ActionApplier) applyUpdateRepRange(ctx context.Context, userID string, targetID *string, payload []byte) error {
	var body struct {
		RoutineID    string `json:"routine_id"`
		TargetRepMin int    `json:"target_rep_min"`
		TargetRepMax int    `json:"target_rep_max"`
	}
	if err := json.Unmarshal(payload, &body); err != nil {
		return err
	}
	min, max := body.TargetRepMin, body.TargetRepMax
	_, err := a.routines.UpdateRoutineExercise(ctx, userID, body.RoutineID, stringPtrVal(targetID), routine.UpdateRoutineExerciseInput{
		TargetRepMin: &min,
		TargetRepMax: &max,
	})
	return err
}

func (a *ActionApplier) applyUpdateRest(ctx context.Context, userID string, targetID *string, payload []byte) error {
	var body struct {
		RoutineID   string `json:"routine_id"`
		RestSeconds int    `json:"rest_seconds"`
	}
	if err := json.Unmarshal(payload, &body); err != nil {
		return err
	}
	rest := body.RestSeconds
	_, err := a.routines.UpdateRoutineExercise(ctx, userID, body.RoutineID, stringPtrVal(targetID), routine.UpdateRoutineExerciseInput{
		RestSeconds: &rest,
	})
	return err
}

func (a *ActionApplier) applyRenameRoutine(ctx context.Context, userID string, targetID *string, payload []byte) error {
	var body struct {
		Name string `json:"name"`
	}
	if err := json.Unmarshal(payload, &body); err != nil {
		return err
	}
	name := body.Name
	_, err := a.routines.UpdateRoutine(ctx, userID, stringPtrVal(targetID), &name, nil)
	return err
}
