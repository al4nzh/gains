package subscription

import (
	"context"

	"gainsai/internal/aiquota"
	"gainsai/internal/user"
)

// RequirePremium returns ErrPremiumRequired when the user is not on a paid plan.
func RequirePremium(ctx context.Context, users *user.Repository, userID string) error {
	u, err := users.GetByID(ctx, userID)
	if err != nil {
		return err
	}
	if !u.IsPremium {
		return aiquota.ErrPremiumRequired
	}
	return nil
}
