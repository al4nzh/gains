package ai

import (
	"context"
	"encoding/json"
)

func (s *Service) coachExerciseLibraryJSON(ctx context.Context) (string, error) {
	if s.exercises == nil {
		return "", nil
	}
	catalog, err := s.exercises.ListCatalog(ctx, "", maxCatalogForLLM, 0)
	if err != nil {
		return "", err
	}
	raw, err := json.Marshal(catalogEntries(catalog))
	if err != nil {
		return "", err
	}
	return string(raw), nil
}

func (s *Service) enrichCoachContextJSON(ctx context.Context, coachJSON []byte) ([]byte, error) {
	libJSON, err := s.coachExerciseLibraryJSON(ctx)
	if err != nil {
		return nil, err
	}
	if libJSON == "" {
		return coachJSON, nil
	}
	var payload map[string]any
	if err := json.Unmarshal(coachJSON, &payload); err != nil {
		return coachJSON, nil
	}
	var lib any
	if err := json.Unmarshal([]byte(libJSON), &lib); err != nil {
		return coachJSON, nil
	}
	payload["exercise_library"] = lib
	return json.Marshal(payload)
}

func (s *Service) coachChatSystemPrompt(ctx context.Context) (string, error) {
	libJSON, err := s.coachExerciseLibraryJSON(ctx)
	if err != nil {
		return "", err
	}
	if libJSON == "" {
		return coachChatSystemPrompt, nil
	}
	return coachChatSystemPrompt + "\n\nGains exercise_library (ONLY these exercises may be used in add/replace actions; copy exercise_name exactly):\n" + libJSON, nil
}
