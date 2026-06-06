package aiquota

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct {
	pool *pgxpool.Pool
}

func NewRepository(pool *pgxpool.Pool) *Repository {
	return &Repository{pool: pool}
}

// TryIncrement adds one usage for today if below limit. Returns false when at or over limit.
func (r *Repository) TryIncrement(ctx context.Context, userID string, kind Kind, limit int) (bool, error) {
	col := kind.column()
	if col == "" {
		return false, fmt.Errorf("aiquota: unknown kind %d", kind)
	}
	q := fmt.Sprintf(`
		WITH upsert AS (
			INSERT INTO ai_daily_usage (user_id, usage_date, %s)
			VALUES ($1, CURRENT_DATE, 1)
			ON CONFLICT (user_id, usage_date) DO UPDATE
			SET %s = ai_daily_usage.%s + 1
			WHERE ai_daily_usage.%s < $2
			RETURNING %s
		)
		SELECT COUNT(*) FROM upsert`, col, col, col, col, col)

	var n int
	if err := r.pool.QueryRow(ctx, q, userID, limit).Scan(&n); err != nil {
		return false, err
	}
	return n == 1, nil
}
