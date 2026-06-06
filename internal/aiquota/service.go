package aiquota

import (
	"context"
	"errors"

	"gainsai/internal/config"
	"gainsai/internal/user"
)

type Service struct {
	repo  *Repository
	users *user.Repository
	cfg   *config.Config
}

func NewService(repo *Repository, users *user.Repository, cfg *config.Config) *Service {
	return &Service{repo: repo, users: users, cfg: cfg}
}

// Consume checks premium access (when enabled) and increments today's usage if under the daily limit.
func (s *Service) Consume(ctx context.Context, userID string, kind Kind) error {
	if s.cfg.AIRequirePremium {
		u, err := s.users.GetByID(ctx, userID)
		if err != nil {
			return err
		}
		if !u.IsPremium {
			return ErrPremiumRequired
		}
	}

	limit := s.limitFor(kind)
	if limit <= 0 {
		return nil
	}

	ok, err := s.repo.TryIncrement(ctx, userID, kind, limit)
	if err != nil {
		return err
	}
	if !ok {
		return ErrDailyQuotaExceeded
	}
	return nil
}

func (s *Service) limitFor(kind Kind) int {
	switch kind {
	case KindCoachMessage:
		return s.cfg.AIDailyCoachMessages
	case KindWorkoutAnalysis:
		return s.cfg.AIDailyWorkoutAnalyses
	case KindRoutineGeneration:
		return s.cfg.AIDailyRoutineGenerations
	case KindPhysiqueScan:
		return s.cfg.AIDailyPhysiqueScans
	default:
		return 0
	}
}

// IsPremiumUser returns whether the user has an active premium flag (for API responses).
func (s *Service) IsPremiumUser(ctx context.Context, userID string) (bool, error) {
	u, err := s.users.GetByID(ctx, userID)
	if err != nil {
		if errors.Is(err, user.ErrNotFound) {
			return false, nil
		}
		return false, err
	}
	return u.IsPremium, nil
}
