package auth

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"gainsai/internal/user"
	"gainsai/internal/email"
)

var (
	ErrInvalidCredentials = errors.New("invalid email or password")
	ErrWeakPassword       = errors.New("password too weak")
)

const minPasswordLength = 8

type Service struct {
	users           *user.Repository
	refresh         *RefreshStore
	emailTokens     *EmailTokenStore
	mailer          email.Mailer
	jwt             *JWTIssuer
	refreshTTL      time.Duration
	googleClientIDs []string
	appleClientID   string
	appName         string
}

func NewService(
	users *user.Repository,
	refresh *RefreshStore,
	emailTokens *EmailTokenStore,
	mailer email.Mailer,
	jwt *JWTIssuer,
	refreshTTL time.Duration,
	googleClientIDs []string,
	appleClientID string,
	appName string,
) *Service {
	return &Service{
		users:           users,
		refresh:         refresh,
		emailTokens:     emailTokens,
		mailer:          mailer,
		jwt:             jwt,
		refreshTTL:      refreshTTL,
		googleClientIDs: googleClientIDs,
		appleClientID:   appleClientID,
		appName:         appName,
	}
}

type ClientInfo struct {
	UserAgent string
	IPAddress string
}

func (s *Service) Register(ctx context.Context, email, password string, info ClientInfo) (*user.User, *TokenPair, error) {
	email = normalizeEmail(email)
	if len(password) < minPasswordLength {
		return nil, nil, ErrWeakPassword
	}
	hash, err := HashPassword(password)
	if err != nil {
		return nil, nil, fmt.Errorf("hash password: %w", err)
	}

	existing, err := s.users.GetByEmail(ctx, email)
	if err != nil && !errors.Is(err, user.ErrNotFound) {
		return nil, nil, err
	}
	if existing != nil {
		if existing.EmailVerified() {
			return nil, nil, user.ErrEmailExists
		}
		if existing.AuthProvider != user.AuthProviderEmail {
			return nil, nil, ErrOAuthEmailConflict
		}
		if err := s.users.UpdatePassword(ctx, existing.ID, hash); err != nil {
			return nil, nil, err
		}
		_ = s.sendVerifyEmail(ctx, existing)
		pair, _, err := s.issueTokens(ctx, existing, info)
		if err != nil {
			return nil, nil, err
		}
		return existing, pair, nil
	}

	u, err := s.users.Create(ctx, email, hash, user.AuthProviderEmail)
	if err != nil {
		return nil, nil, err
	}
	_ = s.sendVerifyEmail(ctx, u)
	pair, _, err := s.issueTokens(ctx, u, info)
	if err != nil {
		return nil, nil, err
	}
	return u, pair, nil
}

func (s *Service) Login(ctx context.Context, email, password string, info ClientInfo) (*user.User, *TokenPair, error) {
	email = normalizeEmail(email)
	u, err := s.users.GetByEmail(ctx, email)
	if err != nil {
		if errors.Is(err, user.ErrNotFound) {
			return nil, nil, ErrInvalidCredentials
		}
		return nil, nil, err
	}
	if u.PasswordHash == nil || !VerifyPassword(*u.PasswordHash, password) {
		return nil, nil, ErrInvalidCredentials
	}
	pair, _, err := s.issueTokens(ctx, u, info)
	if err != nil {
		return nil, nil, err
	}
	return u, pair, nil
}

func (s *Service) Refresh(ctx context.Context, rawToken string, info ClientInfo) (*TokenPair, error) {
	hash := HashRefreshToken(rawToken)
	rt, err := s.refresh.FindByHash(ctx, hash)
	if err != nil {
		return nil, err
	}
	if rt.RevokedAt != nil {
		// Reuse detection: a revoked token is being presented again. Treat as
		// possible theft and revoke the entire family for this user.
		_ = s.refresh.RevokeAllForUser(ctx, rt.UserID)
		return nil, ErrRefreshRevoked
	}
	if time.Now().After(rt.ExpiresAt) {
		return nil, ErrRefreshExpired
	}
	u, err := s.users.GetByID(ctx, rt.UserID)
	if err != nil {
		return nil, err
	}
	pair, newID, err := s.issueTokens(ctx, u, info)
	if err != nil {
		return nil, err
	}
	if err := s.refresh.Revoke(ctx, rt.ID, newID); err != nil {
		return nil, err
	}
	return pair, nil
}

func (s *Service) issueTokens(ctx context.Context, u *user.User, info ClientInfo) (*TokenPair, string, error) {
	access, expiresAt, err := s.jwt.Issue(u.ID, u.Email)
	if err != nil {
		return nil, "", err
	}
	raw, hash, err := GenerateRefreshToken()
	if err != nil {
		return nil, "", err
	}
	var ua, ip *string
	if info.UserAgent != "" {
		ua = &info.UserAgent
	}
	if info.IPAddress != "" {
		ip = &info.IPAddress
	}
	id, err := s.refresh.Create(ctx, u.ID, hash, time.Now().Add(s.refreshTTL), ua, ip)
	if err != nil {
		return nil, "", err
	}
	return &TokenPair{
		AccessToken:  access,
		RefreshToken: raw,
		ExpiresIn:    int(time.Until(expiresAt).Seconds()),
		TokenType:    "Bearer",
	}, id, nil
}

// DeleteAccount permanently removes the user and all related data (DB cascades).
func (s *Service) DeleteAccount(ctx context.Context, userID string) error {
	_ = s.refresh.RevokeAllForUser(ctx, userID)
	return s.users.DeleteByID(ctx, userID)
}

func normalizeEmail(s string) string {
	return strings.ToLower(strings.TrimSpace(s))
}
