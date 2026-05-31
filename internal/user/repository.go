package user

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound    = errors.New("user not found")
	ErrEmailExists = errors.New("email already exists")
)

type Repository struct {
	pool *pgxpool.Pool
}

func NewRepository(pool *pgxpool.Pool) *Repository {
	return &Repository{pool: pool}
}

const userColumns = `id, email, password_hash, auth_provider, email_verified_at, created_at, updated_at`

func (r *Repository) MarkEmailVerified(ctx context.Context, userID string) error {
	_, err := r.pool.Exec(ctx, `
		UPDATE users SET email_verified_at = NOW(), updated_at = NOW()
		WHERE id = $1 AND email_verified_at IS NULL`, userID)
	return err
}

func (r *Repository) UpdatePassword(ctx context.Context, userID, passwordHash string) error {
	_, err := r.pool.Exec(ctx, `
		UPDATE users SET password_hash = $2, updated_at = NOW()
		WHERE id = $1 AND auth_provider = $3`,
		userID, passwordHash, AuthProviderEmail)
	return err
}

func (r *Repository) Create(ctx context.Context, email, passwordHash, authProvider string) (*User, error) {
	const q = `
		INSERT INTO users (email, password_hash, auth_provider)
		VALUES ($1, $2, $3)
		RETURNING ` + userColumns

	rows, _ := r.pool.Query(ctx, q, email, passwordHash, authProvider)
	u, err := pgx.CollectOneRow(rows, pgx.RowToStructByName[User])
	if err != nil {
		if isUniqueViolation(err) {
			return nil, ErrEmailExists
		}
		return nil, err
	}
	return &u, nil
}

func (r *Repository) GetByID(ctx context.Context, id string) (*User, error) {
	rows, _ := r.pool.Query(ctx, `SELECT `+userColumns+` FROM users WHERE id = $1`, id)
	u, err := pgx.CollectOneRow(rows, pgx.RowToStructByName[User])
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &u, nil
}

func (r *Repository) GetByEmail(ctx context.Context, email string) (*User, error) {
	rows, _ := r.pool.Query(ctx, `SELECT `+userColumns+` FROM users WHERE email = $1`, email)
	u, err := pgx.CollectOneRow(rows, pgx.RowToStructByName[User])
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &u, nil
}

func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}
