package ai

import (
	"context"
	"encoding/json"
	"strings"

	"gainsai/internal/actionengine"
	"gainsai/internal/exercise"
	"gainsai/internal/routine"
)

func (s *Service) GenerateRoutineDraft(ctx context.Context, userID string, req GenerateRoutinesRequest) (*GenerateRoutinesResponse, error) {
	msg := strings.TrimSpace(req.Message)
	if msg == "" {
		return nil, ErrRoutineGenMessageRequired
	}
	if strings.TrimSpace(s.cfg.OpenAIAPIKey) == "" {
		return nil, ErrOpenAINotConfigured
	}
	if s.routineDrafts == nil || s.exercises == nil || s.profiles == nil {
		return nil, ErrOpenAINotConfigured
	}

	prof, err := s.profiles.GetByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}

	catalog, err := s.exercises.ListCatalog(ctx, maxCatalogForLLM, 0)
	if err != nil {
		return nil, err
	}

	profilePayload := map[string]any{
		"goal":              prof.FitnessGoal,
		"experience":        prof.TrainingExperience,
		"preferred_split":   prof.PreferredSplit,
		"injury_notes":      prof.InjuryNotes,
		"age":               prof.Age,
		"weight_kg":         prof.WeightKg,
		"height_cm":         prof.HeightCm,
		"activity_level":    prof.ActivityLevel,
	}
	userPayload := map[string]any{
		"request_message":  msg,
		"athlete_profile":  profilePayload,
		"exercise_library": catalogEntries(catalog),
	}
	userJSON, err := json.Marshal(userPayload)
	if err != nil {
		return nil, err
	}

	model := s.cfg.OpenAIModel
	if model == "" {
		model = "gpt-4o-mini"
	}
	raw, err := ChatCompletionMessagesJSON(ctx, s.cfg.OpenAIAPIKey, model, []openAIChatMessage{
		{Role: "system", Content: routineGenSystemPrompt},
		{Role: "user", Content: string(userJSON)},
	})
	if err != nil {
		return nil, err
	}

	var llm llmRoutineGenOutput
	if err := json.Unmarshal([]byte(stripJSONFences(raw)), &llm); err != nil {
		return &GenerateRoutinesResponse{
			Clarification: clarificationFromParseError(),
		}, nil
	}

	resolve := func(name string) (string, []exercise.Exercise, error) {
		return s.exercises.ResolveCatalogByName(ctx, name, 15)
	}
	validated := validateAndResolveRoutineDraft(&llm, catalog, resolve)
	if validated.Clarification != nil {
		return &GenerateRoutinesResponse{Clarification: validated.Clarification}, nil
	}

	draftID, err := s.routineDrafts.Insert(ctx, userID, msg, validated.Draft.Title, validated.Draft)
	if err != nil {
		return nil, err
	}

	return &GenerateRoutinesResponse{
		DraftID:  draftID,
		Title:    validated.Draft.Title,
		Routines: validated.Draft.Routines,
	}, nil
}

func (s *Service) ConfirmRoutineDraft(ctx context.Context, userID, draftID string) (*ConfirmRoutineDraftResponse, error) {
	if s.routineDrafts == nil || s.routineSvc == nil {
		return nil, ErrRoutineDraftNotFound
	}

	row, err := s.routineDrafts.GetForUser(ctx, userID, draftID)
	if err != nil {
		return nil, err
	}
	if row.Status != RoutineDraftStatusDraft {
		return nil, ErrRoutineDraftNotPending
	}

	created := make([]routine.Routine, 0, len(row.Payload.Routines))
	for _, dr := range row.Payload.Routines {
		r, err := s.routineSvc.CreateRoutine(ctx, userID, dr.Name, dr.Description)
		if err != nil {
			return nil, err
		}
		for i, ex := range dr.Exercises {
			pos := i + 1
			_, err := s.routineSvc.AddRoutineExercise(ctx, userID, r.ID, routine.AddRoutineExerciseInput{
				ExerciseID:   ex.ExerciseID,
				TargetSets:   ex.TargetSets,
				TargetRepMin: ex.TargetRepMin,
				TargetRepMax: ex.TargetRepMax,
				RestSeconds:  ex.RestSeconds,
				Notes:        ex.Notes,
				Position:     &pos,
			})
			if err != nil {
				return nil, err
			}
		}
		detail, err := s.routineSvc.GetRoutineDetail(ctx, userID, r.ID)
		if err != nil {
			return nil, err
		}
		created = append(created, *detail)
	}

	if err := s.routineDrafts.MarkConfirmed(ctx, userID, draftID); err != nil {
		return nil, err
	}

	return &ConfirmRoutineDraftResponse{
		DraftID:  draftID,
		Routines: created,
	}, nil
}

func clarificationFromParseError() *actionengine.Clarification {
	return &actionengine.Clarification{
		Required: true,
		Message:  "Could not parse the generated plan. Please try again with a simpler request.",
	}
}
