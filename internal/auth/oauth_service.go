package auth

import (
	"context"
	"errors"

	"gainsai/internal/user"
)

func (s *Service) LoginGoogle(ctx context.Context, idToken string, info ClientInfo) (*user.User, *TokenPair, error) {
	if len(s.googleClientIDs) == 0 {
		return nil, nil, ErrOAuthNotConfigured
	}
	claims, err := verifyGoogleIDToken(ctx, idToken, s.googleClientIDs)
	if err != nil {
		return nil, nil, err
	}
	return s.loginOAuth(ctx, user.AuthProviderGoogle, claims.Subject, claims.Email, info)
}

func (s *Service) LoginApple(ctx context.Context, idToken string, info ClientInfo) (*user.User, *TokenPair, error) {
	if s.appleClientID == "" {
		return nil, nil, ErrOAuthNotConfigured
	}
	claims, err := verifyAppleIDToken(idToken, s.appleClientID)
	if err != nil {
		return nil, nil, err
	}
	return s.loginOAuth(ctx, user.AuthProviderApple, claims.Subject, claims.Email, info)
}

func (s *Service) loginOAuth(ctx context.Context, provider, providerUserID, email string, info ClientInfo) (*user.User, *TokenPair, error) {
	email = normalizeEmail(email)

	ident, err := s.users.GetOAuthIdentity(ctx, provider, providerUserID)
	if err == nil {
		u, err := s.users.GetByID(ctx, ident.UserID)
		if err != nil {
			return nil, nil, err
		}
		pair, _, err := s.issueTokens(ctx, u, info)
		return u, pair, err
	}
	if err != nil && !errors.Is(err, user.ErrNotFound) {
		return nil, nil, err
	}

	if email == "" {
		return nil, nil, ErrOAuthEmailRequired
	}

	existing, err := s.users.GetByEmail(ctx, email)
	if err == nil {
		if err := oauthLinkConflict(existing.AuthProvider, provider); err != nil {
			return nil, nil, err
		}
		if err := s.users.InsertOAuthIdentity(ctx, existing.ID, provider, providerUserID, email); err != nil {
			return nil, nil, err
		}
		if !existing.EmailVerified() {
			_ = s.users.MarkEmailVerified(ctx, existing.ID)
			if u, err := s.users.GetByID(ctx, existing.ID); err == nil {
				existing = u
			}
		}
		pair, _, err := s.issueTokens(ctx, existing, info)
		return existing, pair, err
	}
	if err != nil && !errors.Is(err, user.ErrNotFound) {
		return nil, nil, err
	}

	u, err := s.users.CreateOAuthUser(ctx, email, provider)
	if err != nil {
		return nil, nil, err
	}
	if err := s.users.InsertOAuthIdentity(ctx, u.ID, provider, providerUserID, email); err != nil {
		return nil, nil, err
	}
	pair, _, err := s.issueTokens(ctx, u, info)
	return u, pair, err
}
