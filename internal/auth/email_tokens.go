package auth

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

const (
	TokenPurposeVerifyEmail   = "verify_email"
	TokenPurposeResetPassword = "reset_password"
)

var (
	ErrEmailTokenInvalid = errors.New("invalid or expired token")
	ErrEmailAlreadyVerified = errors.New("email already verified")
	ErrNotEmailAccount   = errors.New("account uses social sign-in")
)

type EmailTokenStore struct {
	pool *pgxpool.Pool
}

func NewEmailTokenStore(pool *pgxpool.Pool) *EmailTokenStore {
	return &EmailTokenStore{pool: pool}
}

type emailTokenRow struct {
	ID        string     `db:"id"`
	UserID    string     `db:"user_id"`
	Purpose   string     `db:"purpose"`
	TokenHash string     `db:"token_hash"`
	ExpiresAt time.Time  `db:"expires_at"`
	UsedAt    *time.Time `db:"used_at"`
}

func (s *EmailTokenStore) InvalidateActive(ctx context.Context, userID, purpose string) error {
	_, err := s.pool.Exec(ctx, `
		UPDATE email_action_tokens SET used_at = NOW()
		WHERE user_id = $1 AND purpose = $2 AND used_at IS NULL AND expires_at > NOW()`,
		userID, purpose)
	return err
}

func (s *EmailTokenStore) Create(ctx context.Context, userID, purpose, hash string, expiresAt time.Time) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO email_action_tokens (user_id, purpose, token_hash, expires_at)
		VALUES ($1, $2, $3, $4)`,
		userID, purpose, hash, expiresAt)
	return err
}

func (s *EmailTokenStore) Consume(ctx context.Context, purpose, hash string) (userID string, err error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id, user_id, purpose, token_hash, expires_at, used_at
		FROM email_action_tokens
		WHERE token_hash = $1 AND purpose = $2
		FOR UPDATE`, hash, purpose)
	if err != nil {
		return "", err
	}
	row, err := pgx.CollectOneRow(rows, pgx.RowToStructByName[emailTokenRow])
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", ErrEmailTokenInvalid
		}
		return "", err
	}
	if row.UsedAt != nil || time.Now().After(row.ExpiresAt) {
		return "", ErrEmailTokenInvalid
	}
	_, err = s.pool.Exec(ctx, `UPDATE email_action_tokens SET used_at = NOW() WHERE id = $1`, row.ID)
	if err != nil {
		return "", err
	}
	return row.UserID, nil
}
