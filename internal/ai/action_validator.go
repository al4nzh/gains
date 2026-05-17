package ai

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"gainsai/internal/actionengine"
	"gainsai/internal/exercise"
	"gainsai/internal/profile"
	"gainsai/internal/routine"
)

const maxProposedActionsPerChat = 8

var supportedCoachActionTypes = map[string]struct{}{
	actionengine.ActionUpdateGoal:                    {},
	actionengine.ActionUpdateInjuryNotes:             {},
	actionengine.ActionUpdateBodyweight:              {},
	actionengine.ActionUpdateHeight:                  {},
	actionengine.ActionAddExerciseToRoutine:          {},
	actionengine.ActionRemoveExerciseFromRoutine:     {},
	actionengine.ActionReplaceExerciseInRoutine:      {},
	actionengine.ActionUpdateRoutineExerciseSets:     {},
	actionengine.ActionUpdateRoutineExerciseRepRange: {},
	actionengine.ActionUpdateRoutineExerciseRest:     {},
	actionengine.ActionRenameRoutine:                 {},
}

type proposedAction struct {
	ActionType string          `json:"action_type"`
	TargetType string          `json:"target_type"`
	TargetID   *string         `json:"target_id"`
	Payload    json.RawMessage `json:"payload"`
	Reason     string          `json:"reason"`
}

type validatedAction struct {
	ActionType string
	TargetType string
	TargetID   *string
	Payload    []byte
	Reason     *string
}

type ActionValidator struct {
	profiles  *profile.Repository
	routines  *routine.Repository
	exercises *exercise.Repository
}

func NewActionValidator(profiles *profile.Repository, routines *routine.Repository, exercises *exercise.Repository) *ActionValidator {
	return &ActionValidator{profiles: profiles, routines: routines, exercises: exercises}
}

type validateBatchResult struct {
	Valid         []validatedAction
	Clarification *actionengine.Clarification
}

func (v *ActionValidator) ValidateProposed(ctx context.Context, userID string, raw []proposedAction) validateBatchResult {
	out := validateBatchResult{Valid: make([]validatedAction, 0, len(raw))}
	if len(raw) > maxProposedActionsPerChat {
		raw = raw[:maxProposedActionsPerChat]
	}
	var clar *actionengine.Clarification
	for i, p := range raw {
		va, c, err := v.validateOne(ctx, userID, p)
		if err != nil {
			continue
		}
		if c != nil {
			if clar == nil {
				clar = c
			} else {
				clar.Message += fmt.Sprintf(" (also action %d)", i+1)
			}
			continue
		}
		if va != nil {
			out.Valid = append(out.Valid, *va)
		}
	}
	out.Clarification = clar
	return out
}

func (v *ActionValidator) ValidateStored(ctx context.Context, userID string, a *actionengine.Action) (*validatedAction, error) {
	p := proposedAction{
		ActionType: a.ActionType,
		TargetType: stringPtrVal(a.TargetType),
		TargetID:   a.TargetID,
		Payload:    a.Payload,
	}
	if a.Reason != nil {
		p.Reason = *a.Reason
	}
	va, c, err := v.validateOne(ctx, userID, p)
	if err != nil {
		return nil, err
	}
	if c != nil {
		return nil, ErrExerciseAmbiguous
	}
	if va == nil {
		return nil, ErrActionValidation
	}
	return va, nil
}

func (v *ActionValidator) validateOne(ctx context.Context, userID string, p proposedAction) (*validatedAction, *actionengine.Clarification, error) {
	p.ActionType = strings.TrimSpace(p.ActionType)
	p.TargetType = strings.TrimSpace(p.TargetType)
	if _, ok := supportedCoachActionTypes[p.ActionType]; !ok {
		return nil, nil, ErrUnsupportedAction
	}
	reason := strings.TrimSpace(p.Reason)
	var reasonPtr *string
	if reason != "" {
		if len(reason) > 500 {
			reason = reason[:500]
		}
		reasonPtr = &reason
	}

	switch p.ActionType {
	case actionengine.ActionUpdateGoal:
		return v.validateUpdateGoal(ctx, userID, p, reasonPtr)
	case actionengine.ActionUpdateInjuryNotes:
		return v.validateUpdateInjuryNotes(ctx, userID, p, reasonPtr)
	case actionengine.ActionUpdateBodyweight:
		return v.validateUpdateBodyweight(ctx, userID, p, reasonPtr)
	case actionengine.ActionUpdateHeight:
		return v.validateUpdateHeight(ctx, userID, p, reasonPtr)
	case actionengine.ActionAddExerciseToRoutine:
		return v.validateAddExercise(ctx, userID, p, reasonPtr)
	case actionengine.ActionRemoveExerciseFromRoutine:
		return v.validateRemoveExercise(ctx, userID, p, reasonPtr)
	case actionengine.ActionReplaceExerciseInRoutine:
		return v.validateReplaceExercise(ctx, userID, p, reasonPtr)
	case actionengine.ActionUpdateRoutineExerciseSets:
		return v.validateUpdateSets(ctx, userID, p, reasonPtr)
	case actionengine.ActionUpdateRoutineExerciseRepRange:
		return v.validateUpdateRepRange(ctx, userID, p, reasonPtr)
	case actionengine.ActionUpdateRoutineExerciseRest:
		return v.validateUpdateRest(ctx, userID, p, reasonPtr)
	case actionengine.ActionRenameRoutine:
		return v.validateRenameRoutine(ctx, userID, p, reasonPtr)
	default:
		return nil, nil, ErrUnsupportedAction
	}
}

func (v *ActionValidator) validateUpdateGoal(ctx context.Context, userID string, p proposedAction, reason *string) (*validatedAction, *actionengine.Clarification, error) {
	var body struct {
		Goal        *string `json:"goal"`
		FitnessGoal *string `json:"fitness_goal"`
	}
	if err := json.Unmarshal(p.Payload, &body); err != nil {
		return nil, nil, ErrActionValidation
	}
	g := strPtr(body.Goal)
	if g == "" {
		g = strPtr(body.FitnessGoal)
	}
	if g == "" {
		return nil, nil, ErrActionValidation
	}
	prof, _ := v.profiles.GetByUserID(ctx, userID)
	if prof == nil {
		prof = &profile.Profile{UserID: userID}
	}
	prof.FitnessGoal = &g
	if err := profile.Validate(prof); err != nil {
		return nil, nil, err
	}
	payload, _ := json.Marshal(map[string]string{"goal": g})
	return &validatedAction{
		ActionType: p.ActionType,
		TargetType: actionengine.TargetTypeProfile,
		TargetID:   &userID,
		Payload:    payload,
		Reason:     reason,
	}, nil, nil
}

func (v *ActionValidator) validateUpdateInjuryNotes(ctx context.Context, userID string, p proposedAction, reason *string) (*validatedAction, *actionengine.Clarification, error) {
	var body struct {
		InjuryNotes *string `json:"injury_notes"`
		Value       *string `json:"value"`
	}
	if err := json.Unmarshal(p.Payload, &body); err != nil {
		return nil, nil, ErrActionValidation
	}
	notes := body.InjuryNotes
	if notes == nil {
		notes = body.Value
	}
	if notes == nil {
		return nil, nil, ErrActionValidation
	}
	n := strings.TrimSpace(*notes)
	prof, _ := v.profiles.GetByUserID(ctx, userID)
	if prof == nil {
		prof = &profile.Profile{UserID: userID}
	}
	if n == "" {
		prof.InjuryNotes = nil
	} else {
		prof.InjuryNotes = &n
	}
	if err := profile.Validate(prof); err != nil {
		return nil, nil, err
	}
	payload, _ := json.Marshal(map[string]*string{"injury_notes": prof.InjuryNotes})
	return &validatedAction{
		ActionType: p.ActionType,
		TargetType: actionengine.TargetTypeProfile,
		TargetID:   &userID,
		Payload:    payload,
		Reason:     reason,
	}, nil, nil
}

func (v *ActionValidator) validateUpdateBodyweight(ctx context.Context, userID string, p proposedAction, reason *string) (*validatedAction, *actionengine.Clarification, error) {
	var body struct {
		WeightKg   *float64 `json:"weight_kg"`
		Bodyweight *float64 `json:"bodyweight"`
		Value      *float64 `json:"value"`
	}
	if err := json.Unmarshal(p.Payload, &body); err != nil {
		return nil, nil, ErrActionValidation
	}
	w := body.WeightKg
	if w == nil {
		w = body.Bodyweight
	}
	if w == nil {
		w = body.Value
	}
	if w == nil {
		return nil, nil, ErrActionValidation
	}
	prof, _ := v.profiles.GetByUserID(ctx, userID)
	if prof == nil {
		prof = &profile.Profile{UserID: userID}
	}
	prof.WeightKg = w
	if err := profile.Validate(prof); err != nil {
		return nil, nil, err
	}
	payload, _ := json.Marshal(map[string]float64{"weight_kg": *w})
	return &validatedAction{
		ActionType: p.ActionType,
		TargetType: actionengine.TargetTypeProfile,
		TargetID:   &userID,
		Payload:    payload,
		Reason:     reason,
	}, nil, nil
}

func (v *ActionValidator) validateUpdateHeight(ctx context.Context, userID string, p proposedAction, reason *string) (*validatedAction, *actionengine.Clarification, error) {
	var body struct {
		HeightCm *float64 `json:"height_cm"`
		Height   *float64 `json:"height"`
		Value    *float64 `json:"value"`
	}
	if err := json.Unmarshal(p.Payload, &body); err != nil {
		return nil, nil, ErrActionValidation
	}
	h := body.HeightCm
	if h == nil {
		h = body.Height
	}
	if h == nil {
		h = body.Value
	}
	if h == nil {
		return nil, nil, ErrActionValidation
	}
	prof, _ := v.profiles.GetByUserID(ctx, userID)
	if prof == nil {
		prof = &profile.Profile{UserID: userID}
	}
	prof.HeightCm = h
	if err := profile.Validate(prof); err != nil {
		return nil, nil, err
	}
	payload, _ := json.Marshal(map[string]float64{"height_cm": *h})
	return &validatedAction{
		ActionType: p.ActionType,
		TargetType: actionengine.TargetTypeProfile,
		TargetID:   &userID,
		Payload:    payload,
		Reason:     reason,
	}, nil, nil
}

func (v *ActionValidator) validateRenameRoutine(ctx context.Context, userID string, p proposedAction, reason *string) (*validatedAction, *actionengine.Clarification, error) {
	routineID, err := v.requireRoutineTarget(ctx, userID, p)
	if err != nil {
		return nil, nil, err
	}
	var body struct {
		Name  *string `json:"name"`
		Value *string `json:"value"`
	}
	if err := json.Unmarshal(p.Payload, &body); err != nil {
		return nil, nil, ErrActionValidation
	}
	name := strPtr(body.Name)
	if name == "" {
		name = strPtr(body.Value)
	}
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, nil, ErrActionValidation
	}
	payload, _ := json.Marshal(map[string]string{"name": name})
	tid := routineID
	return &validatedAction{
		ActionType: p.ActionType,
		TargetType: actionengine.TargetTypeRoutine,
		TargetID:   &tid,
		Payload:    payload,
		Reason:     reason,
	}, nil, nil
}

func (v *ActionValidator) validateAddExercise(ctx context.Context, userID string, p proposedAction, reason *string) (*validatedAction, *actionengine.Clarification, error) {
	routineID, err := v.requireRoutineTarget(ctx, userID, p)
	if err != nil {
		return nil, nil, err
	}
	var body struct {
		ExerciseID   *string `json:"exercise_id"`
		ExerciseName *string `json:"exercise_name"`
		TargetSets   *int    `json:"target_sets"`
		TargetRepMin *int    `json:"target_rep_min"`
		TargetRepMax *int    `json:"target_rep_max"`
		RestSeconds  *int    `json:"rest_seconds"`
		Position     *int    `json:"position"`
	}
	if err := json.Unmarshal(p.Payload, &body); err != nil {
		return nil, nil, ErrActionValidation
	}
	exID, clar := v.resolveExerciseID(ctx, body.ExerciseID, body.ExerciseName)
	if clar != nil {
		return nil, clar, nil
	}
	if exID == "" {
		return nil, nil, ErrExerciseNotResolved
	}
	if body.TargetRepMin != nil || body.TargetRepMax != nil {
		if err := validateRepRangePtr(body.TargetRepMin, body.TargetRepMax); err != nil {
			return nil, nil, err
		}
	}
	canonical, _ := json.Marshal(map[string]any{
		"routine_id":     routineID,
		"exercise_id":    exID,
		"exercise_name":  strPtr(body.ExerciseName),
		"target_sets":    body.TargetSets,
		"target_rep_min": body.TargetRepMin,
		"target_rep_max": body.TargetRepMax,
		"rest_seconds":   body.RestSeconds,
		"position":       body.Position,
	})
	tid := routineID
	return &validatedAction{
		ActionType: p.ActionType,
		TargetType: actionengine.TargetTypeRoutine,
		TargetID:   &tid,
		Payload:    canonical,
		Reason:     reason,
	}, nil, nil
}

func (v *ActionValidator) validateRemoveExercise(ctx context.Context, userID string, p proposedAction, reason *string) (*validatedAction, *actionengine.Clarification, error) {
	rowID, _, payload, err := v.requireRoutineExercise(ctx, userID, p)
	if err != nil {
		return nil, nil, err
	}
	tid := rowID
	return &validatedAction{
		ActionType: p.ActionType,
		TargetType: actionengine.TargetTypeRoutineExercise,
		TargetID:   &tid,
		Payload:    payload,
		Reason:     reason,
	}, nil, nil
}

func (v *ActionValidator) validateReplaceExercise(ctx context.Context, userID string, p proposedAction, reason *string) (*validatedAction, *actionengine.Clarification, error) {
	rowID, routineID, basePayload, err := v.requireRoutineExercise(ctx, userID, p)
	if err != nil {
		return nil, nil, err
	}
	var body struct {
		ExerciseID      *string `json:"exercise_id"`
		ExerciseName    *string `json:"exercise_name"`
		NewExerciseID   *string `json:"new_exercise_id"`
		NewExerciseName *string `json:"new_exercise_name"`
	}
	if err := json.Unmarshal(p.Payload, &body); err != nil {
		return nil, nil, ErrActionValidation
	}
	newID := strPtr(body.NewExerciseID)
	if newID == "" {
		newID = strPtr(body.ExerciseID)
	}
	newName := body.NewExerciseName
	if newName == nil {
		newName = body.ExerciseName
	}
	var idPtr *string
	if newID != "" {
		idPtr = &newID
	}
	resolved, clar := v.resolveExerciseID(ctx, idPtr, newName)
	if clar != nil {
		return nil, clar, nil
	}
	if resolved == "" {
		return nil, nil, ErrExerciseNotResolved
	}
	var pl map[string]any
	_ = json.Unmarshal(basePayload, &pl)
	pl["new_exercise_id"] = resolved
	pl["routine_id"] = routineID
	canonical, _ := json.Marshal(pl)
	tid := rowID
	return &validatedAction{
		ActionType: p.ActionType,
		TargetType: actionengine.TargetTypeRoutineExercise,
		TargetID:   &tid,
		Payload:    canonical,
		Reason:     reason,
	}, nil, nil
}

func (v *ActionValidator) validateUpdateSets(ctx context.Context, userID string, p proposedAction, reason *string) (*validatedAction, *actionengine.Clarification, error) {
	rowID, _, basePayload, err := v.requireRoutineExercise(ctx, userID, p)
	if err != nil {
		return nil, nil, err
	}
	var body struct {
		TargetSets *int `json:"target_sets"`
	}
	if err := json.Unmarshal(p.Payload, &body); err != nil || body.TargetSets == nil {
		return nil, nil, ErrActionValidation
	}
	if *body.TargetSets < 1 || *body.TargetSets > 20 {
		return nil, nil, errors.New("target_sets out of range")
	}
	var pl map[string]any
	_ = json.Unmarshal(basePayload, &pl)
	pl["target_sets"] = *body.TargetSets
	canonical, _ := json.Marshal(pl)
	tid := rowID
	return &validatedAction{
		ActionType: p.ActionType,
		TargetType: actionengine.TargetTypeRoutineExercise,
		TargetID:   &tid,
		Payload:    canonical,
		Reason:     reason,
	}, nil, nil
}

func (v *ActionValidator) validateUpdateRepRange(ctx context.Context, userID string, p proposedAction, reason *string) (*validatedAction, *actionengine.Clarification, error) {
	rowID, _, basePayload, err := v.requireRoutineExercise(ctx, userID, p)
	if err != nil {
		return nil, nil, err
	}
	var body struct {
		TargetRepMin *int `json:"target_rep_min"`
		TargetRepMax *int `json:"target_rep_max"`
	}
	if err := json.Unmarshal(p.Payload, &body); err != nil {
		return nil, nil, ErrActionValidation
	}
	if err := validateRepRangePtr(body.TargetRepMin, body.TargetRepMax); err != nil {
		return nil, nil, err
	}
	var pl map[string]any
	_ = json.Unmarshal(basePayload, &pl)
	pl["target_rep_min"] = *body.TargetRepMin
	pl["target_rep_max"] = *body.TargetRepMax
	canonical, _ := json.Marshal(pl)
	tid := rowID
	return &validatedAction{
		ActionType: p.ActionType,
		TargetType: actionengine.TargetTypeRoutineExercise,
		TargetID:   &tid,
		Payload:    canonical,
		Reason:     reason,
	}, nil, nil
}

func (v *ActionValidator) validateUpdateRest(ctx context.Context, userID string, p proposedAction, reason *string) (*validatedAction, *actionengine.Clarification, error) {
	rowID, _, basePayload, err := v.requireRoutineExercise(ctx, userID, p)
	if err != nil {
		return nil, nil, err
	}
	var body struct {
		RestSeconds *int `json:"rest_seconds"`
	}
	if err := json.Unmarshal(p.Payload, &body); err != nil || body.RestSeconds == nil {
		return nil, nil, ErrActionValidation
	}
	if *body.RestSeconds < 0 || *body.RestSeconds > 600 {
		return nil, nil, errors.New("rest_seconds out of range")
	}
	var pl map[string]any
	_ = json.Unmarshal(basePayload, &pl)
	pl["rest_seconds"] = *body.RestSeconds
	canonical, _ := json.Marshal(pl)
	tid := rowID
	return &validatedAction{
		ActionType: p.ActionType,
		TargetType: actionengine.TargetTypeRoutineExercise,
		TargetID:   &tid,
		Payload:    canonical,
		Reason:     reason,
	}, nil, nil
}

func (v *ActionValidator) requireRoutineTarget(ctx context.Context, userID string, p proposedAction) (string, error) {
	routineID := strings.TrimSpace(stringPtrVal(p.TargetID))
	var body struct {
		RoutineID string `json:"routine_id"`
	}
	_ = json.Unmarshal(p.Payload, &body)
	if routineID == "" {
		routineID = strings.TrimSpace(body.RoutineID)
	}
	if routineID == "" || p.TargetType != actionengine.TargetTypeRoutine {
		return "", ErrActionValidation
	}
	if _, err := v.routines.GetRoutineForUser(ctx, userID, routineID); err != nil {
		return "", err
	}
	return routineID, nil
}

func (v *ActionValidator) requireRoutineExercise(ctx context.Context, userID string, p proposedAction) (rowID, routineID string, payload []byte, err error) {
	rowID = strings.TrimSpace(stringPtrVal(p.TargetID))
	var body struct {
		RoutineID         string  `json:"routine_id"`
		RoutineExerciseID string  `json:"routine_exercise_id"`
		ExerciseID        string  `json:"exercise_id"`
		ExerciseName      *string `json:"exercise_name"`
	}
	_ = json.Unmarshal(p.Payload, &body)
	if rowID == "" {
		rowID = strings.TrimSpace(body.RoutineExerciseID)
	}
	if rowID == "" {
		return "", "", nil, ErrActionValidation
	}
	if p.TargetType != actionengine.TargetTypeRoutineExercise {
		return "", "", nil, ErrActionValidation
	}
	routineID = strings.TrimSpace(body.RoutineID)
	if routineID == "" {
		return "", "", nil, ErrActionValidation
	}
	if _, err := v.routines.GetRoutineForUser(ctx, userID, routineID); err != nil {
		return "", "", nil, err
	}
	ex, err := v.routines.ListRoutineExercises(ctx, routineID)
	if err != nil {
		return "", "", nil, err
	}
	var found *routine.RoutineExerciseOut
	for i := range ex {
		if ex[i].ID == rowID {
			found = &ex[i]
			break
		}
	}
	if found == nil {
		return "", "", nil, routine.ErrRoutineExerciseNotFound
	}
	if body.ExerciseID != "" && body.ExerciseID != found.ExerciseID {
		return "", "", nil, ErrActionValidation
	}
	canonical, _ := json.Marshal(map[string]any{
		"routine_id":          routineID,
		"routine_exercise_id": rowID,
		"exercise_id":         found.ExerciseID,
		"exercise_name":       found.ExerciseName,
	})
	return rowID, routineID, canonical, nil
}

func (v *ActionValidator) resolveExerciseID(ctx context.Context, id *string, name *string) (string, *actionengine.Clarification) {
	if id != nil {
		s := strings.TrimSpace(*id)
		if s != "" {
			ok, err := v.routines.ExerciseExists(ctx, s)
			if err != nil || !ok {
				return "", nil
			}
			return s, nil
		}
	}
	n := strPtr(name)
	if n == "" {
		return "", nil
	}
	resolved, ambiguous, err := v.exercises.ResolveCatalogByName(ctx, n, 12)
	if err != nil {
		return "", nil
	}
	if resolved != "" {
		return resolved, nil
	}
	if len(ambiguous) == 0 {
		return "", nil
	}
	matches := make([]actionengine.ExerciseMatch, 0, len(ambiguous))
	for _, ex := range ambiguous {
		matches = append(matches, actionengine.ExerciseMatch{ExerciseID: ex.ID, ExerciseName: ex.Name})
	}
	return "", &actionengine.Clarification{
		Required:        true,
		Message:         "Which exercise did you mean?",
		PossibleMatches: matches,
	}
}

func validateRepRangePtr(min, max *int) error {
	if min == nil || max == nil {
		return ErrActionValidation
	}
	if *min < 0 || *max < 0 || *min > *max {
		return errors.New("invalid rep range")
	}
	if *max > 100 {
		return errors.New("rep range out of range")
	}
	return nil
}

func stringPtrVal(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func strPtr(s *string) string {
	if s == nil {
		return ""
	}
	return strings.TrimSpace(*s)
}

