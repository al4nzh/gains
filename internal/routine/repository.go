package routine

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct {
	pool *pgxpool.Pool
}

func NewRepository(pool *pgxpool.Pool) *Repository {
	return &Repository{pool: pool}
}

const routineCols = `id, user_id, name, description, created_at, updated_at`

func (r *Repository) CreateRoutine(ctx context.Context, userID, name string, description *string) (*Routine, error) {
	const q = `
		INSERT INTO routines (user_id, name, description)
		VALUES ($1, $2, $3)
		RETURNING ` + routineCols
	rows, _ := r.pool.Query(ctx, q, userID, name, description)
	out, err := pgx.CollectOneRow(rows, pgx.RowToStructByName[Routine])
	if err != nil {
		return nil, err
	}
	return &out, nil
}

type routineListRow struct {
	ID            string         `db:"id"`
	UserID        string         `db:"user_id"`
	Name          string         `db:"name"`
	Description   sql.NullString `db:"description"`
	CreatedAt     time.Time      `db:"created_at"`
	UpdatedAt     time.Time      `db:"updated_at"`
	ExerciseCount int            `db:"exercise_count"`
}

func (r *Repository) ListRoutinesByUser(ctx context.Context, userID string) ([]Routine, error) {
	const q = `
		SELECT r.id, r.user_id, r.name, r.description, r.created_at, r.updated_at,
			COALESCE(COUNT(re.id), 0)::int AS exercise_count
		FROM routines r
		LEFT JOIN routine_exercises re ON re.routine_id = r.id
		WHERE r.user_id = $1
		GROUP BY r.id, r.user_id, r.name, r.description, r.created_at, r.updated_at
		ORDER BY r.updated_at DESC`
	rows, err := r.pool.Query(ctx, q, userID)
	if err != nil {
		return nil, err
	}
	raw, err := pgx.CollectRows(rows, pgx.RowToStructByName[routineListRow])
	if err != nil {
		return nil, err
	}
	out := make([]Routine, 0, len(raw))
	for _, row := range raw {
		var desc *string
		if row.Description.Valid {
			s := row.Description.String
			desc = &s
		}
		out = append(out, Routine{
			ID:            row.ID,
			UserID:        row.UserID,
			Name:          row.Name,
			Description:   desc,
			CreatedAt:     row.CreatedAt,
			UpdatedAt:     row.UpdatedAt,
			ExerciseCount: row.ExerciseCount,
		})
	}
	return out, nil
}

func (r *Repository) GetRoutineForUser(ctx context.Context, userID, routineID string) (*Routine, error) {
	const q = `SELECT ` + routineCols + ` FROM routines WHERE id = $1 AND user_id = $2`
	rows, _ := r.pool.Query(ctx, q, routineID, userID)
	out, err := pgx.CollectOneRow(rows, pgx.RowToStructByName[Routine])
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &out, nil
}

func (r *Repository) DeleteRoutine(ctx context.Context, userID, routineID string) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM routines WHERE id = $1 AND user_id = $2`, routineID, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *Repository) UpdateRoutineMeta(ctx context.Context, userID, routineID, name string, description *string) error {
	tag, err := r.pool.Exec(ctx, `
		UPDATE routines SET name = $1, description = $2, updated_at = NOW()
		WHERE id = $3 AND user_id = $4
	`, name, description, routineID, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

type exerciseRow struct {
	ID             string   `db:"id"`
	RoutineID      string   `db:"routine_id"`
	ExerciseID     string   `db:"exercise_id"`
	Position       int      `db:"position"`
	TargetSets     *int     `db:"target_sets"`
	TargetRepMin   *int     `db:"target_rep_min"`
	TargetRepMax   *int     `db:"target_rep_max"`
	TargetRPE      *float64 `db:"target_rpe"`
	RestSeconds    *int     `db:"rest_seconds"`
	Notes          *string  `db:"notes"`
	TargetWeightKg *float64 `db:"target_weight_kg"`
	ExerciseName   string   `db:"exercise_name"`
}

func (r *Repository) ListRoutineExercises(ctx context.Context, routineID string) ([]RoutineExerciseOut, error) {
	const q = `
		SELECT re.id, re.routine_id, re.exercise_id, re.position, re.target_sets,
			re.target_rep_min, re.target_rep_max, re.target_rpe, re.rest_seconds, re.notes, re.target_weight_kg,
			e.name AS exercise_name
		FROM routine_exercises re
		JOIN exercises e ON e.id = re.exercise_id
		WHERE re.routine_id = $1
		ORDER BY re.position ASC, re.id ASC`
	rows, err := r.pool.Query(ctx, q, routineID)
	if err != nil {
		return nil, err
	}
	raw, err := pgx.CollectRows(rows, pgx.RowToStructByName[exerciseRow])
	if err != nil {
		return nil, err
	}
	out := make([]RoutineExerciseOut, 0, len(raw))
	for _, row := range raw {
		out = append(out, exerciseRowToOut(row))
	}
	return out, nil
}

func exerciseRowToOut(row exerciseRow) RoutineExerciseOut {
	return RoutineExerciseOut{
		RoutineExercise: RoutineExercise{
			ID:             row.ID,
			RoutineID:      row.RoutineID,
			ExerciseID:     row.ExerciseID,
			Position:       row.Position,
			TargetSets:     row.TargetSets,
			TargetRepMin:   row.TargetRepMin,
			TargetRepMax:   row.TargetRepMax,
			TargetRPE:      row.TargetRPE,
			RestSeconds:    row.RestSeconds,
			Notes:          row.Notes,
			TargetWeightKg: row.TargetWeightKg,
		},
		ExerciseName: row.ExerciseName,
	}
}

func (r *Repository) ExerciseExists(ctx context.Context, exerciseID string) (bool, error) {
	var n int
	err := r.pool.QueryRow(ctx, `SELECT 1 FROM exercises WHERE id = $1 LIMIT 1`, exerciseID).Scan(&n)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return false, nil
		}
		return false, err
	}
	return true, nil
}

func (r *Repository) AddRoutineExercise(ctx context.Context, routineID, exerciseID string, targetSets, repMin, repMax, rest *int, rpe *float64, notes *string, position *int) (*RoutineExerciseOut, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}

	rows, err := tx.Query(ctx, `
		SELECT re.id, re.routine_id, re.exercise_id, re.position, re.target_sets,
			re.target_rep_min, re.target_rep_max, re.target_rpe, re.rest_seconds, re.notes, re.target_weight_kg,
			e.name AS exercise_name
		FROM routine_exercises re
		JOIN exercises e ON e.id = re.exercise_id
		WHERE re.routine_id = $1
		ORDER BY re.position ASC, re.id ASC`, routineID)
	if err != nil {
		_ = tx.Rollback(ctx)
		return nil, err
	}
	existing, err := pgx.CollectRows(rows, pgx.RowToStructByName[exerciseRow])
	if err != nil {
		_ = tx.Rollback(ctx)
		return nil, err
	}

	ids := make([]string, 0, len(existing)+1)
	for _, e := range existing {
		ids = append(ids, e.ID)
	}

	newID, err := insertRoutineExerciseRow(ctx, tx, routineID, exerciseID, targetSets, repMin, repMax, rest, rpe, notes)
	if err != nil {
		_ = tx.Rollback(ctx)
		return nil, err
	}
	ids = append(ids, newID)

	newPos := len(ids)
	if position != nil && *position >= 1 {
		newPos = *position
		if newPos > len(ids) {
			newPos = len(ids)
		}
	}
	// move newID to index newPos-1 in ids order: current order is [...existing, new at end]
	newIDAtEnd := ids[len(ids)-1]
	ids = ids[:len(ids)-1]
	idx := newPos - 1
	if idx < 0 {
		idx = 0
	}
	if idx > len(ids) {
		idx = len(ids)
	}
	ids = append(ids[:idx], append([]string{newIDAtEnd}, ids[idx:]...)...)

	if err := applyRoutineExerciseOrder(ctx, tx, routineID, ids); err != nil {
		_ = tx.Rollback(ctx)
		return nil, err
	}
	if _, err := tx.Exec(ctx, `UPDATE routines SET updated_at = NOW() WHERE id = $1`, routineID); err != nil {
		_ = tx.Rollback(ctx)
		return nil, err
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return r.getRoutineExerciseOut(ctx, routineID, newID)
}

func insertRoutineExerciseRow(ctx context.Context, tx pgx.Tx, routineID, exerciseID string, targetSets, repMin, repMax, rest *int, rpe *float64, notes *string) (string, error) {
	var id string
	err := tx.QueryRow(ctx, `
		INSERT INTO routine_exercises (
			routine_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes
		) VALUES ($1, $2, 999999, $3, $4, $5, $6, $7, $8)
		RETURNING id
	`, routineID, exerciseID, targetSets, repMin, repMax, rpe, rest, notes).Scan(&id)
	return id, err
}

func applyRoutineExerciseOrder(ctx context.Context, tx pgx.Tx, routineID string, orderedIDs []string) error {
	// Two-phase updates avoid UNIQUE (routine_id, position) collisions while reordering.
	const tempBase = 100_000
	for i, id := range orderedIDs {
		if _, err := tx.Exec(ctx, `UPDATE routine_exercises SET position = $1 WHERE id = $2 AND routine_id = $3`, tempBase+i, id, routineID); err != nil {
			return err
		}
	}
	for i, id := range orderedIDs {
		if _, err := tx.Exec(ctx, `UPDATE routine_exercises SET position = $1 WHERE id = $2 AND routine_id = $3`, i+1, id, routineID); err != nil {
			return err
		}
	}
	return nil
}

func (r *Repository) getRoutineExerciseOut(ctx context.Context, routineID, rowID string) (*RoutineExerciseOut, error) {
	const q = `
		SELECT re.id, re.routine_id, re.exercise_id, re.position, re.target_sets,
			re.target_rep_min, re.target_rep_max, re.target_rpe, re.rest_seconds, re.notes, re.target_weight_kg,
			e.name AS exercise_name
		FROM routine_exercises re
		JOIN exercises e ON e.id = re.exercise_id
		WHERE re.routine_id = $1 AND re.id = $2`
	rows, _ := r.pool.Query(ctx, q, routineID, rowID)
	row, err := pgx.CollectOneRow(rows, pgx.RowToStructByName[exerciseRow])
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrRoutineExerciseNotFound
		}
		return nil, err
	}
	o := exerciseRowToOut(row)
	return &o, nil
}

type patchRoutineExercise struct {
	TargetSets   *int
	RepMin       *int
	RepMax       *int
	TargetRPE    *float64
	RestSeconds  *int
	Notes        *string
	Position     *int
	ClearNotes   bool
}

func collectIDRows(rows pgx.Rows) ([]string, error) {
	return pgx.CollectRows(rows, func(row pgx.CollectableRow) (string, error) {
		var id string
		err := row.Scan(&id)
		return id, err
	})
}

func (r *Repository) UpdateRoutineExercise(ctx context.Context, routineID, rowID string, p patchRoutineExercise) (*RoutineExerciseOut, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}

	var check string
	err = tx.QueryRow(ctx, `SELECT id FROM routine_exercises WHERE id = $1 AND routine_id = $2`, rowID, routineID).Scan(&check)
	if err != nil {
		_ = tx.Rollback(ctx)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrRoutineExerciseNotFound
		}
		return nil, err
	}

	if p.Position != nil {
		rows, err := tx.Query(ctx, `
			SELECT id FROM routine_exercises WHERE routine_id = $1 ORDER BY position ASC, id ASC`, routineID)
		if err != nil {
			_ = tx.Rollback(ctx)
			return nil, err
		}
		ids, err := collectIDRows(rows)
		if err != nil {
			_ = tx.Rollback(ctx)
			return nil, err
		}
		newPos := *p.Position
		if newPos < 1 || newPos > len(ids) {
			_ = tx.Rollback(ctx)
			return nil, ErrInvalidPosition
		}
		filtered := make([]string, 0, len(ids))
		for _, id := range ids {
			if id != rowID {
				filtered = append(filtered, id)
			}
		}
		idx := newPos - 1
		if idx > len(filtered) {
			idx = len(filtered)
		}
		filtered = append(filtered[:idx], append([]string{rowID}, filtered[idx:]...)...)
		if err := applyRoutineExerciseOrder(ctx, tx, routineID, filtered); err != nil {
			_ = tx.Rollback(ctx)
			return nil, err
		}
	}

	args := []any{routineID, rowID}
	setSQL := ""
	n := 3
	add := func(col string, v any) {
		if setSQL != "" {
			setSQL += ", "
		}
		setSQL += fmt.Sprintf("%s = $%d", col, n)
		args = append(args, v)
		n++
	}
	if p.TargetSets != nil {
		add("target_sets", *p.TargetSets)
	}
	if p.RepMin != nil {
		add("target_rep_min", *p.RepMin)
	}
	if p.RepMax != nil {
		add("target_rep_max", *p.RepMax)
	}
	if p.TargetRPE != nil {
		add("target_rpe", *p.TargetRPE)
	}
	if p.RestSeconds != nil {
		add("rest_seconds", *p.RestSeconds)
	}
	if p.ClearNotes {
		if setSQL != "" {
			setSQL += ", "
		}
		setSQL += "notes = NULL"
	} else if p.Notes != nil {
		add("notes", *p.Notes)
	}

	if setSQL != "" {
		q := `UPDATE routine_exercises SET ` + setSQL + ` WHERE routine_id = $1 AND id = $2`
		if _, err := tx.Exec(ctx, q, args...); err != nil {
			_ = tx.Rollback(ctx)
			return nil, err
		}
	}

	if _, err := tx.Exec(ctx, `UPDATE routines SET updated_at = NOW() WHERE id = $1`, routineID); err != nil {
		_ = tx.Rollback(ctx)
		return nil, err
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return r.getRoutineExerciseOut(ctx, routineID, rowID)
}

// ReplaceRoutineExercise swaps the catalog exercise on an existing routine line (same row id / position).
func (r *Repository) ReplaceRoutineExercise(ctx context.Context, userID, routineID, rowID, newExerciseID string) (*RoutineExerciseOut, error) {
	if _, err := r.GetRoutineForUser(ctx, userID, routineID); err != nil {
		return nil, err
	}
	ok, err := r.ExerciseExists(ctx, newExerciseID)
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, ErrExerciseNotFound
	}
	tag, err := r.pool.Exec(ctx, `
		UPDATE routine_exercises SET exercise_id = $3
		WHERE id = $1 AND routine_id = $2`, rowID, routineID, newExerciseID)
	if err != nil {
		return nil, err
	}
	if tag.RowsAffected() == 0 {
		return nil, ErrRoutineExerciseNotFound
	}
	_, _ = r.pool.Exec(ctx, `UPDATE routines SET updated_at = NOW() WHERE id = $1`, routineID)
	return r.getRoutineExerciseOut(ctx, routineID, rowID)
}

func (r *Repository) DeleteRoutineExercise(ctx context.Context, userID, routineID, rowID string) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}

	var rid string
	err = tx.QueryRow(ctx, `
		SELECT r.id FROM routines r
		WHERE r.id = $1 AND r.user_id = $2`, routineID, userID).Scan(&rid)
	if err != nil {
		_ = tx.Rollback(ctx)
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrNotFound
		}
		return err
	}

	tag, err := tx.Exec(ctx, `DELETE FROM routine_exercises WHERE id = $1 AND routine_id = $2`, rowID, routineID)
	if err != nil {
		_ = tx.Rollback(ctx)
		return err
	}
	if tag.RowsAffected() == 0 {
		_ = tx.Rollback(ctx)
		return ErrRoutineExerciseNotFound
	}

	rows, err := tx.Query(ctx, `SELECT id FROM routine_exercises WHERE routine_id = $1 ORDER BY position ASC, id ASC`, routineID)
	if err != nil {
		_ = tx.Rollback(ctx)
		return err
	}
	ids, err := collectIDRows(rows)
	if err != nil {
		_ = tx.Rollback(ctx)
		return err
	}
	if err := applyRoutineExerciseOrder(ctx, tx, routineID, ids); err != nil {
		_ = tx.Rollback(ctx)
		return err
	}
	if _, err := tx.Exec(ctx, `UPDATE routines SET updated_at = NOW() WHERE id = $1`, routineID); err != nil {
		_ = tx.Rollback(ctx)
		return err
	}
	return tx.Commit(ctx)
}

// --- templates ---

type templateListRow struct {
	ID            string         `db:"id"`
	Name          string         `db:"name"`
	Description   sql.NullString `db:"description"`
	CreatedAt     time.Time      `db:"created_at"`
	ExerciseCount int            `db:"exercise_count"`
}

func (r *Repository) ListRoutineTemplates(ctx context.Context) ([]RoutineTemplate, error) {
	const q = `
		SELECT t.id, t.name, t.description, t.created_at,
			(SELECT COUNT(*)::int FROM routine_template_exercises te WHERE te.template_id = t.id) AS exercise_count
		FROM routine_templates t
		ORDER BY t.name ASC`
	rows, err := r.pool.Query(ctx, q)
	if err != nil {
		return nil, err
	}
	raw, err := pgx.CollectRows(rows, pgx.RowToStructByName[templateListRow])
	if err != nil {
		return nil, err
	}
	out := make([]RoutineTemplate, 0, len(raw))
	for _, row := range raw {
		var desc *string
		if row.Description.Valid {
			s := row.Description.String
			desc = &s
		}
		out = append(out, RoutineTemplate{
			ID:            row.ID,
			Name:          row.Name,
			Description:   desc,
			CreatedAt:     row.CreatedAt,
			ExerciseCount: row.ExerciseCount,
		})
	}
	return out, nil
}

func (r *Repository) GetRoutineTemplate(ctx context.Context, templateID string) (*RoutineTemplate, error) {
	const q = `SELECT id, name, description, created_at FROM routine_templates WHERE id = $1`
	rows, _ := r.pool.Query(ctx, q, templateID)
	t, err := pgx.CollectOneRow(rows, pgx.RowToStructByName[RoutineTemplate])
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrTemplateNotFound
		}
		return nil, err
	}
	return &t, nil
}

type templateExerciseRow struct {
	ID           string   `db:"id"`
	TemplateID   string   `db:"template_id"`
	ExerciseID   string   `db:"exercise_id"`
	Position     int      `db:"position"`
	TargetSets   *int     `db:"target_sets"`
	TargetRepMin *int     `db:"target_rep_min"`
	TargetRepMax *int     `db:"target_rep_max"`
	TargetRPE    *float64 `db:"target_rpe"`
	RestSeconds  *int     `db:"rest_seconds"`
	Notes        *string  `db:"notes"`
	ExerciseName string   `db:"exercise_name"`
}

func (r *Repository) ListTemplateExercises(ctx context.Context, templateID string) ([]RoutineTemplateExerciseOut, error) {
	const q = `
		SELECT te.id, te.template_id, te.exercise_id, te.position, te.target_sets,
			te.target_rep_min, te.target_rep_max, te.target_rpe, te.rest_seconds, te.notes,
			e.name AS exercise_name
		FROM routine_template_exercises te
		JOIN exercises e ON e.id = te.exercise_id
		WHERE te.template_id = $1
		ORDER BY te.position ASC, te.id ASC`
	rows, err := r.pool.Query(ctx, q, templateID)
	if err != nil {
		return nil, err
	}
	raw, err := pgx.CollectRows(rows, pgx.RowToStructByName[templateExerciseRow])
	if err != nil {
		return nil, err
	}
	out := make([]RoutineTemplateExerciseOut, 0, len(raw))
	for _, row := range raw {
		out = append(out, RoutineTemplateExerciseOut{
			RoutineTemplateExercise: RoutineTemplateExercise{
				ID:           row.ID,
				TemplateID:   row.TemplateID,
				ExerciseID:   row.ExerciseID,
				Position:     row.Position,
				TargetSets:   row.TargetSets,
				TargetRepMin: row.TargetRepMin,
				TargetRepMax: row.TargetRepMax,
				TargetRPE:    row.TargetRPE,
				RestSeconds:  row.RestSeconds,
				Notes:        row.Notes,
			},
			ExerciseName: row.ExerciseName,
		})
	}
	return out, nil
}

func (r *Repository) CopyTemplateToUserRoutine(ctx context.Context, userID, templateID string, routineName string) (*Routine, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}

	var tname string
	var desc sql.NullString
	err = tx.QueryRow(ctx, `SELECT name, description FROM routine_templates WHERE id = $1`, templateID).Scan(&tname, &desc)
	if err != nil {
		_ = tx.Rollback(ctx)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrTemplateNotFound
		}
		return nil, err
	}
	finalName := routineName
	if finalName == "" {
		finalName = tname
	}
	var descPtr *string
	if desc.Valid {
		s := desc.String
		descPtr = &s
	}

	rows, err := tx.Query(ctx, `
		INSERT INTO routines (user_id, name, description)
		VALUES ($1, $2, $3)
		RETURNING `+routineCols, userID, finalName, descPtr)
	if err != nil {
		_ = tx.Rollback(ctx)
		return nil, err
	}
	routine, err := pgx.CollectOneRow(rows, pgx.RowToStructByName[Routine])
	if err != nil {
		_ = tx.Rollback(ctx)
		return nil, err
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO routine_exercises (
			routine_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes
		)
		SELECT $1::uuid, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes
		FROM routine_template_exercises
		WHERE template_id = $2
		ORDER BY position ASC`, routine.ID, templateID)
	if err != nil {
		_ = tx.Rollback(ctx)
		return nil, err
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return &routine, nil
}

