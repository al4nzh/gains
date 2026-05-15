package exercise

import (
	"context"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct {
	pool *pgxpool.Pool
}

func NewRepository(pool *pgxpool.Pool) *Repository {
	return &Repository{pool: pool}
}

const exerciseColumns = `id, name, muscle_group, equipment, is_custom, created_by, created_at`

const catalogWhere = `is_custom = FALSE AND created_by IS NULL`

// ListCatalog returns system exercises ordered by name.
func (r *Repository) ListCatalog(ctx context.Context, limit, offset int) ([]Exercise, error) {
	q := fmt.Sprintf(`
		SELECT %s FROM exercises
		WHERE %s
		ORDER BY name ASC
		LIMIT $1 OFFSET $2
	`, exerciseColumns, catalogWhere)
	rows, err := r.pool.Query(ctx, q, limit, offset)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, pgx.RowToStructByName[Exercise])
}

// SearchCatalog searches system exercise names (case-insensitive substring).
func (r *Repository) SearchCatalog(ctx context.Context, query string, limit int) ([]Exercise, error) {
	esc := strings.ReplaceAll(query, `\`, `\\`)
	esc = strings.ReplaceAll(esc, "%", `\%`)
	esc = strings.ReplaceAll(esc, "_", `\_`)
	pattern := "%" + esc + "%"
	q := fmt.Sprintf(`
		SELECT %s FROM exercises
		WHERE %s AND name ILIKE $1 ESCAPE '\'
		ORDER BY name ASC
		LIMIT $2
	`, exerciseColumns, catalogWhere)
	rows, err := r.pool.Query(ctx, q, pattern, limit)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, pgx.RowToStructByName[Exercise])
}

// GetNamesByIDs returns exercise id -> name for any exercise rows (catalog or custom).
func (r *Repository) GetNamesByIDs(ctx context.Context, ids []string) (map[string]string, error) {
	if len(ids) == 0 {
		return map[string]string{}, nil
	}
	rows, err := r.pool.Query(ctx, `SELECT id::text, name FROM exercises WHERE id::text = ANY($1)`, ids)
	if err != nil {
		return nil, err
	}
	out := make(map[string]string)
	for rows.Next() {
		var id, name string
		if err := rows.Scan(&id, &name); err != nil {
			return nil, err
		}
		out[id] = name
	}
	return out, rows.Err()
}
