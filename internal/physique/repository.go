package physique

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct {
	pool *pgxpool.Pool
}

func NewRepository(pool *pgxpool.Pool) *Repository {
	return &Repository{pool: pool}
}

func (r *Repository) NewScanID(ctx context.Context) (string, error) {
	var id string
	err := r.pool.QueryRow(ctx, `SELECT gen_random_uuid()::text`).Scan(&id)
	return id, err
}

func (r *Repository) Insert(ctx context.Context, userID, scanID string, pct int, confidence, summary, reasoning string) (*Scan, error) {
	const q = `
		INSERT INTO physique_scans (id, user_id, estimated_body_fat_pct, confidence, summary, reasoning)
		VALUES ($1::uuid, $2::uuid, $3, $4, $5, $6)
		RETURNING id::text, user_id::text, estimated_body_fat_pct, confidence, summary, reasoning, created_at`
	row := r.pool.QueryRow(ctx, q, scanID, userID, pct, confidence, summary, reasoning)
	return scanRow(row)
}

func (r *Repository) GetByID(ctx context.Context, userID, scanID string) (*Scan, error) {
	const q = `
		SELECT id::text, user_id::text, estimated_body_fat_pct, confidence, summary, reasoning, created_at
		FROM physique_scans
		WHERE id = $1::uuid AND user_id = $2::uuid`
	row := r.pool.QueryRow(ctx, q, scanID, userID)
	s, err := scanRow(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return s, nil
}

func (r *Repository) ListByUser(ctx context.Context, userID string, limit int) ([]Scan, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	const q = `
		SELECT id::text, user_id::text, estimated_body_fat_pct, confidence, summary, reasoning, created_at
		FROM physique_scans
		WHERE user_id = $1::uuid
		ORDER BY created_at DESC
		LIMIT $2`
	rows, err := r.pool.Query(ctx, q, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []Scan
	for rows.Next() {
		s, err := scanRows(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *s)
	}
	return out, rows.Err()
}

type scannable interface {
	Scan(dest ...any) error
}

func scanRow(row scannable) (*Scan, error) {
	var s Scan
	if err := row.Scan(&s.ID, &s.UserID, &s.EstimatedBodyFatPct, &s.Confidence, &s.Summary, &s.Reasoning, &s.CreatedAt); err != nil {
		return nil, err
	}
	return &s, nil
}

func scanRows(rows pgx.Rows) (*Scan, error) {
	var s Scan
	if err := rows.Scan(&s.ID, &s.UserID, &s.EstimatedBodyFatPct, &s.Confidence, &s.Summary, &s.Reasoning, &s.CreatedAt); err != nil {
		return nil, err
	}
	return &s, nil
}
