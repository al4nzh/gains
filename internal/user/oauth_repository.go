package user

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
)

type OAuthIdentity struct {
	ID             string `db:"id"`
	UserID         string `db:"user_id"`
	Provider       string `db:"provider"`
	ProviderUserID string `db:"provider_user_id"`
	Email          *string `db:"email"`
}

func (r *Repository) GetOAuthIdentity(ctx context.Context, provider, providerUserID string) (*OAuthIdentity, error) {
	const q = `
		SELECT id::text, user_id::text, provider, provider_user_id, email
		FROM user_oauth_identities
		WHERE provider = $1 AND provider_user_id = $2`
	rows, err := r.pool.Query(ctx, q, provider, providerUserID)
	if err != nil {
		return nil, err
	}
	ident, err := pgx.CollectOneRow(rows, pgx.RowToStructByName[OAuthIdentity])
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &ident, nil
}

func (r *Repository) CreateOAuthUser(ctx context.Context, email, authProvider string) (*User, error) {
	const q = `
		INSERT INTO users (email, password_hash, auth_provider)
		VALUES ($1, NULL, $2)
		RETURNING ` + userColumns
	rows, err := r.pool.Query(ctx, q, email, authProvider)
	if err != nil {
		if isUniqueViolation(err) {
			return nil, ErrEmailExists
		}
		return nil, err
	}
	u, err := pgx.CollectOneRow(rows, pgx.RowToStructByName[User])
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func (r *Repository) InsertOAuthIdentity(ctx context.Context, userID, provider, providerUserID, email string) error {
	var em *string
	if email != "" {
		em = &email
	}
	_, err := r.pool.Exec(ctx, `
		INSERT INTO user_oauth_identities (user_id, provider, provider_user_id, email)
		VALUES ($1::uuid, $2, $3, $4)`,
		userID, provider, providerUserID, em,
	)
	if isUniqueViolation(err) {
		return ErrEmailExists
	}
	return err
}
