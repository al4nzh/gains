package exercise

import (
	"context"
	"errors"
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
// If muscleGroup is non-empty, results are limited to that catalog muscle_group value.
func (r *Repository) ListCatalog(ctx context.Context, muscleGroup string, limit, offset int) ([]Exercise, error) {
	muscleGroup = strings.TrimSpace(strings.ToLower(muscleGroup))
	args := []any{limit, offset}
	groupClause := ""
	if muscleGroup != "" {
		groupClause = " AND lower(muscle_group) = $3"
		args = append(args, muscleGroup)
	}
	q := fmt.Sprintf(`
		SELECT %s FROM exercises
		WHERE %s%s
		ORDER BY name ASC
		LIMIT $1 OFFSET $2
	`, exerciseColumns, catalogWhere, groupClause)
	rows, err := r.pool.Query(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, pgx.RowToStructByName[Exercise])
}

// SearchCatalog searches system exercise names (case-insensitive substring).
// If muscleGroup is non-empty, results are limited to that catalog muscle_group value.
func (r *Repository) SearchCatalog(ctx context.Context, query, muscleGroup string, limit int) ([]Exercise, error) {
	muscleGroup = strings.TrimSpace(strings.ToLower(muscleGroup))
	esc := strings.ReplaceAll(query, `\`, `\\`)
	esc = strings.ReplaceAll(esc, "%", `\%`)
	esc = strings.ReplaceAll(esc, "_", `\_`)
	pattern := "%" + esc + "%"
	args := []any{pattern, limit}
	groupClause := ""
	if muscleGroup != "" {
		groupClause = " AND lower(muscle_group) = $3"
		args = append(args, muscleGroup)
	}
	q := fmt.Sprintf(`
		SELECT %s FROM exercises
		WHERE %s AND name ILIKE $1 ESCAPE '\'%s
		ORDER BY name ASC
		LIMIT $2
	`, exerciseColumns, catalogWhere, groupClause)
	rows, err := r.pool.Query(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, pgx.RowToStructByName[Exercise])
}

// CatalogExerciseExists reports whether id is a system catalog exercise (not user custom).
func (r *Repository) CatalogExerciseExists(ctx context.Context, exerciseID string) (bool, error) {
	exerciseID = strings.TrimSpace(exerciseID)
	if exerciseID == "" {
		return false, nil
	}
	var n int
	err := r.pool.QueryRow(ctx, `
		SELECT 1 FROM exercises
		WHERE id = $1 AND `+catalogWhere+`
		LIMIT 1`, exerciseID).Scan(&n)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return false, nil
		}
		return false, err
	}
	return true, nil
}

// ResolveCatalogByName returns a unique catalog exercise id for an exact name match (case-insensitive).
// If zero or multiple exact matches exist, ambiguous lists candidates from a name search.
func (r *Repository) ResolveCatalogByName(ctx context.Context, name string, searchLimit int) (exerciseID string, ambiguous []Exercise, err error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return "", nil, nil
	}
	if searchLimit < 1 {
		searchLimit = 10
	}
	if searchLimit > 25 {
		searchLimit = 25
	}
	candidates, err := r.SearchCatalog(ctx, name, "", searchLimit)
	if err != nil {
		return "", nil, err
	}
	var exact []Exercise
	for _, ex := range candidates {
		if strings.EqualFold(strings.TrimSpace(ex.Name), name) {
			exact = append(exact, ex)
		}
	}
	switch len(exact) {
	case 1:
		return exact[0].ID, nil, nil
	case 0:
		if len(candidates) == 0 {
			return "", nil, nil
		}
		return "", candidates, nil
	default:
		return "", exact, nil
	}
}

type ExerciseMeta struct {
	ID          string
	Name        string
	MuscleGroup string
}

// GetMetaByIDs returns id, name, and muscle_group for exercises.
func (r *Repository) GetMetaByIDs(ctx context.Context, ids []string) (map[string]ExerciseMeta, error) {
	if len(ids) == 0 {
		return map[string]ExerciseMeta{}, nil
	}
	rows, err := r.pool.Query(ctx, `
		SELECT id::text, name, COALESCE(muscle_group, '')
		FROM exercises WHERE id::text = ANY($1)`, ids)
	if err != nil {
		return nil, err
	}
	out := make(map[string]ExerciseMeta)
	for rows.Next() {
		var m ExerciseMeta
		if err := rows.Scan(&m.ID, &m.Name, &m.MuscleGroup); err != nil {
			return nil, err
		}
		out[m.ID] = m
	}
	return out, rows.Err()
}

// LookupMeta holds fields needed to resolve external exercise media.
type LookupMeta struct {
	ID        string
	Name      string
	Equipment string
}

// GetLookupMetaByIDs returns id, name, and equipment for exercises.
func (r *Repository) GetLookupMetaByIDs(ctx context.Context, ids []string) (map[string]LookupMeta, error) {
	if len(ids) == 0 {
		return map[string]LookupMeta{}, nil
	}
	rows, err := r.pool.Query(ctx, `
		SELECT id::text, name, COALESCE(equipment, '')
		FROM exercises WHERE id::text = ANY($1)`, ids)
	if err != nil {
		return nil, err
	}
	out := make(map[string]LookupMeta)
	for rows.Next() {
		var m LookupMeta
		if err := rows.Scan(&m.ID, &m.Name, &m.Equipment); err != nil {
			return nil, err
		}
		out[m.ID] = m
	}
	return out, rows.Err()
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
