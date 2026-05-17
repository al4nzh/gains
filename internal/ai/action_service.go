package ai

import (
	"context"

	"gainsai/internal/actionengine"
)

func (s *Service) ListPendingActions(ctx context.Context, userID string, limit int) ([]actionengine.Action, error) {
	if s.actions == nil {
		return []actionengine.Action{}, nil
	}
	list, err := s.actions.ListPending(ctx, userID, limit)
	if err != nil {
		return nil, err
	}
	if list == nil {
		return []actionengine.Action{}, nil
	}
	return list, nil
}

func (s *Service) AcceptAction(ctx context.Context, userID, actionID string) (*actionengine.Action, error) {
	if s.actions == nil || s.actionVal == nil || s.actionApply == nil {
		return nil, ErrActionNotFound
	}
	cur, err := s.actions.GetForUser(ctx, userID, actionID)
	if err != nil {
		return nil, err
	}
	if cur.Status != actionengine.StatusPending {
		return nil, ErrActionNotPending
	}
	va, err := s.actionVal.ValidateStored(ctx, userID, cur)
	if err != nil {
		return nil, err
	}
	if err := s.actionApply.Apply(ctx, userID, va); err != nil {
		return nil, err
	}
	return s.actions.MarkApplied(ctx, userID, actionID)
}

func (s *Service) RejectAction(ctx context.Context, userID, actionID string) (*actionengine.Action, error) {
	if s.actions == nil {
		return nil, ErrActionNotFound
	}
	return s.actions.MarkRejected(ctx, userID, actionID)
}
