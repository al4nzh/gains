package auth

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrRefreshNotFound = errors.New("refresh token not found")
	ErrRefreshRevoked  = errors.New("refresh token revoked")
	ErrRefreshExpired  = errors.New("refresh token expired")
)

type RefreshToken struct {
	ID         string     `db:"id"`
	UserID     string     `db:"user_id"`
	TokenHash  string     `db:"token_hash"`
	ExpiresAt  time.Time  `db:"expires_at"`
	CreatedAt  time.Time  `db:"created_at"`
	RevokedAt  *time.Time `db:"revoked_at"`
	ReplacedBy *string    `db:"replaced_by"`
	UserAgent  *string    `db:"user_agent"`
	IPAddress  *string    `db:"ip_address"`
}

type RefreshStore struct {
	pool *pgxpool.Pool
}

func NewRefreshStore(pool *pgxpool.Pool) *RefreshStore {
	return &RefreshStore{pool: pool}
}

// GenerateRefreshToken returns the raw token (sent to client) and its sha256
// hash (stored in DB). Raw tokens are never persisted.
func GenerateRefreshToken() (raw, hashed string, err error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", "", err
	}
	raw = hex.EncodeToString(b)
	hashed = HashRefreshToken(raw)
	return raw, hashed, nil
}

func HashRefreshToken(raw string) string {
	sum := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(sum[:])
}

func (s *RefreshStore) Create(ctx context.Context, userID, hash string, expiresAt time.Time, userAgent, ip *string) (string, error) {
	var id string
	err := s.pool.QueryRow(ctx, `
		INSERT INTO refresh_tokens (user_id, token_hash, expires_at, user_agent, ip_address)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id
	`, userID, hash, expiresAt, userAgent, ip).Scan(&id)
	return id, err
}

func (s *RefreshStore) FindByHash(ctx context.Context, hash string) (*RefreshToken, error) {
	rows, _ := s.pool.Query(ctx, `
		SELECT id, user_id, token_hash, expires_at, created_at, revoked_at, replaced_by, user_agent, ip_address
		FROM refresh_tokens
		WHERE token_hash = $1
	`, hash)
	rt, err := pgx.CollectOneRow(rows, pgx.RowToStructByName[RefreshToken])
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrRefreshNotFound
		}
		return nil, err
	}
	return &rt, nil
}

func (s *RefreshStore) Revoke(ctx context.Context, id, replacedBy string) error {
	var rb interface{}
	if replacedBy != "" {
		rb = replacedBy
	}
	_, err := s.pool.Exec(ctx, `
		UPDATE refresh_tokens
		SET revoked_at = NOW(), replaced_by = $2
		WHERE id = $1 AND revoked_at IS NULL
	`, id, rb)
	return err
}

// RevokeAllForUser is used as a defensive measure when reuse of a revoked
// token is detected, signalling possible theft.
func (s *RefreshStore) RevokeAllForUser(ctx context.Context, userID string) error {
	_, err := s.pool.Exec(ctx, `
		UPDATE refresh_tokens
		SET revoked_at = NOW()
		WHERE user_id = $1 AND revoked_at IS NULL
	`, userID)
	return err
}
