package auth

import (
	"context"
	"crypto/rand"
	"encoding/binary"
	"fmt"
	"strings"
	"time"

	"gainsai/internal/email"
	"gainsai/internal/user"
)

const (
	verifyEmailTokenTTL  = 24 * time.Hour
	resetPasswordTokenTTL = time.Hour
)

func (s *Service) sendVerifyEmail(ctx context.Context, u *user.User) error {
	if s.mailer == nil || u.AuthProvider != user.AuthProviderEmail {
		return nil
	}
	if u.EmailVerifiedAt != nil {
		return nil
	}
	raw, hash, err := generateEmailCode()
	if err != nil {
		return err
	}
	if err := s.emailTokens.InvalidateActive(ctx, u.ID, TokenPurposeVerifyEmail); err != nil {
		return err
	}
	if err := s.emailTokens.Create(ctx, u.ID, TokenPurposeVerifyEmail, hash, time.Now().Add(verifyEmailTokenTTL)); err != nil {
		return err
	}
	subject, body := email.VerificationBody(s.appName, raw)
	return s.mailer.Send(ctx, u.Email, subject, body)
}

func (s *Service) VerifyEmail(ctx context.Context, rawToken string) (*user.User, error) {
	rawToken = normalizeEmailCode(rawToken)
	if rawToken == "" {
		return nil, ErrEmailTokenInvalid
	}
	hash := HashRefreshToken(rawToken)
	userID, err := s.emailTokens.Consume(ctx, TokenPurposeVerifyEmail, hash)
	if err != nil {
		return nil, err
	}
	if err := s.users.MarkEmailVerified(ctx, userID); err != nil {
		return nil, err
	}
	return s.users.GetByID(ctx, userID)
}

func (s *Service) ResendVerification(ctx context.Context, userID string) error {
	u, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return err
	}
	if u.AuthProvider != user.AuthProviderEmail {
		return ErrNotEmailAccount
	}
	if u.EmailVerifiedAt != nil {
		return ErrEmailAlreadyVerified
	}
	return s.sendVerifyEmail(ctx, u)
}

func (s *Service) ResendVerificationByEmail(ctx context.Context, emailAddr string) error {
	u, err := s.users.GetByEmail(ctx, normalizeEmail(emailAddr))
	if err != nil {
		if err == user.ErrNotFound {
			return nil // do not leak
		}
		return err
	}
	if u.AuthProvider != user.AuthProviderEmail || u.EmailVerifiedAt != nil {
		return nil
	}
	return s.sendVerifyEmail(ctx, u)
}

func (s *Service) ForgotPassword(ctx context.Context, emailAddr string) error {
	u, err := s.users.GetByEmail(ctx, normalizeEmail(emailAddr))
	if err != nil {
		if err == user.ErrNotFound {
			return nil
		}
		return err
	}
	if u.AuthProvider != user.AuthProviderEmail || u.PasswordHash == nil {
		return nil
	}
	raw, hash, err := generateEmailCode()
	if err != nil {
		return err
	}
	if err := s.emailTokens.InvalidateActive(ctx, u.ID, TokenPurposeResetPassword); err != nil {
		return err
	}
	if err := s.emailTokens.Create(ctx, u.ID, TokenPurposeResetPassword, hash, time.Now().Add(resetPasswordTokenTTL)); err != nil {
		return err
	}
	subject, body := email.ResetPasswordBody(s.appName, raw)
	return s.mailer.Send(ctx, u.Email, subject, body)
}

func (s *Service) ResetPassword(ctx context.Context, rawToken, newPassword string) error {
	if len(newPassword) < minPasswordLength {
		return ErrWeakPassword
	}
	rawToken = normalizeEmailCode(rawToken)
	if rawToken == "" {
		return ErrEmailTokenInvalid
	}
	hash := HashRefreshToken(rawToken)
	userID, err := s.emailTokens.Consume(ctx, TokenPurposeResetPassword, hash)
	if err != nil {
		return err
	}
	pwHash, err := HashPassword(newPassword)
	if err != nil {
		return err
	}
	return s.users.UpdatePassword(ctx, userID, pwHash)
}

func generateEmailCode() (raw, hashed string, err error) {
	var n uint32
	if err := binary.Read(rand.Reader, binary.BigEndian, &n); err != nil {
		return "", "", err
	}
	raw = fmt.Sprintf("%06d", n%1_000_000)
	hashed = HashRefreshToken(raw)
	return raw, hashed, nil
}

func normalizeEmailCode(s string) string {
	s = strings.TrimSpace(s)
	s = strings.ReplaceAll(s, " ", "")
	return s
}
