package ai

import (
	"context"
	"encoding/json"
	"strings"

	"gainsai/internal/actionengine"
)

type coachChatLLMResponse struct {
	Message          string           `json:"message"`
	ProposedActions  []proposedAction `json:"proposed_actions"`
}

func parseCoachChatLLM(raw string) (coachChatLLMResponse, error) {
	raw = stripJSONFences(strings.TrimSpace(raw))
	var out coachChatLLMResponse
	if err := json.Unmarshal([]byte(raw), &out); err != nil {
		return coachChatLLMResponse{Message: raw}, err
	}
	if strings.TrimSpace(out.Message) == "" && len(out.ProposedActions) == 0 {
		out.Message = raw
	}
	return out, nil
}

func (s *Service) persistProposedActions(ctx context.Context, userID, convID string, proposed []proposedAction) ([]actionengine.Action, *actionengine.Clarification, error) {
	if s.actions == nil || s.actionVal == nil || len(proposed) == 0 {
		return nil, nil, nil
	}
	batch := s.actionVal.ValidateProposed(ctx, userID, proposed)
	saved := make([]actionengine.Action, 0, len(batch.Valid))
	for _, va := range batch.Valid {
		a, err := s.actions.Insert(ctx, insertActionInput{
			UserID:     userID,
			SourceType: actionengine.SourceTypeChat,
			SourceID:   &convID,
			ActionType: va.ActionType,
			TargetType: va.TargetType,
			TargetID:   va.TargetID,
			Payload:    va.Payload,
			Reason:     va.Reason,
		})
		if err != nil {
			return saved, batch.Clarification, err
		}
		saved = append(saved, *a)
	}
	return saved, batch.Clarification, nil
}
