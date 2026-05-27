package workout

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
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

const workoutCols = `id, user_id, routine_id, name, started_at, completed_at, notes, created_at, total_volume_kg, duration_seconds, stats, adaptive_adjustments`

func (r *Repository) CreateWorkout(ctx context.Context, userID string, routineID *string, name *string) (*Workout, error) {
	const q = `
		INSERT INTO workouts (user_id, routine_id, name)
		VALUES ($1, $2, $3)
		RETURNING ` + workoutCols
	rows, _ := r.pool.Query(ctx, q, userID, routineID, name)
	w, err := pgx.CollectOneRow(rows, pgx.RowToStructByName[Workout])
	if err != nil {
		return nil, err
	}
	return &w, nil
}

func (r *Repository) RoutineOwnedBy(ctx context.Context, userID, routineID string) (bool, error) {
	var n int
	err := r.pool.QueryRow(ctx, `SELECT 1 FROM routines WHERE id = $1 AND user_id = $2`, routineID, userID).Scan(&n)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return false, nil
		}
		return false, err
	}
	return true, nil
}

func (r *Repository) GetActiveWorkoutForUser(ctx context.Context, userID string) (*Workout, error) {
	const q = `SELECT ` + workoutCols + `
		FROM workouts
		WHERE user_id = $1 AND completed_at IS NULL
		ORDER BY started_at DESC
		LIMIT 1`
	rows, _ := r.pool.Query(ctx, q, userID)
	w, err := pgx.CollectOneRow(rows, pgx.RowToStructByName[Workout])
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &w, nil
}

func (r *Repository) DeleteActiveWorkout(ctx context.Context, userID, workoutID string) error {
	tag, err := r.pool.Exec(ctx, `
		DELETE FROM workouts
		WHERE id = $1 AND user_id = $2 AND completed_at IS NULL`,
		workoutID, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *Repository) GetWorkoutForUser(ctx context.Context, userID, workoutID string) (*Workout, error) {
	const q = `SELECT ` + workoutCols + ` FROM workouts WHERE id = $1 AND user_id = $2`
	rows, _ := r.pool.Query(ctx, q, workoutID, userID)
	w, err := pgx.CollectOneRow(rows, pgx.RowToStructByName[Workout])
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &w, nil
}

func (r *Repository) ListWorkoutsByUser(ctx context.Context, userID string, limit int) ([]Workout, error) {
	if limit < 1 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
	const q = `SELECT ` + workoutCols + ` FROM workouts WHERE user_id = $1 ORDER BY started_at DESC LIMIT $2`
	rows, err := r.pool.Query(ctx, q, userID, limit)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, pgx.RowToStructByName[Workout])
}

type setRow struct {
	Set
	ExerciseName string `db:"exercise_name"`
}

func (r *Repository) ListSetsForWorkout(ctx context.Context, workoutID string) ([]SetOut, error) {
	const q = `
		SELECT ws.id, ws.workout_id, ws.exercise_id, ws.set_number, ws.reps, ws.weight_kg, ws.rpe, ws.is_failure, ws.notes, ws.created_at,
			e.name AS exercise_name
		FROM workout_sets ws
		JOIN exercises e ON e.id = ws.exercise_id
		WHERE ws.workout_id = $1
		ORDER BY ws.exercise_id, ws.set_number ASC, ws.created_at ASC`
	rows, err := r.pool.Query(ctx, q, workoutID)
	if err != nil {
		return nil, err
	}
	raw, err := pgx.CollectRows(rows, pgx.RowToStructByName[setRow])
	if err != nil {
		return nil, err
	}
	out := make([]SetOut, 0, len(raw))
	for _, row := range raw {
		out = append(out, SetOut{Set: row.Set, ExerciseName: row.ExerciseName})
	}
	return out, nil
}

func (r *Repository) ExerciseExists(ctx context.Context, exerciseID string) (bool, error) {
	var x int
	err := r.pool.QueryRow(ctx, `SELECT 1 FROM exercises WHERE id = $1`, exerciseID).Scan(&x)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return false, nil
		}
		return false, err
	}
	return true, nil
}

func (r *Repository) NextSetNumber(ctx context.Context, workoutID, exerciseID string) (int, error) {
	var m sql.NullInt64
	err := r.pool.QueryRow(ctx, `
		SELECT MAX(set_number) FROM workout_sets WHERE workout_id = $1 AND exercise_id = $2`,
		workoutID, exerciseID).Scan(&m)
	if err != nil {
		return 0, err
	}
	if !m.Valid {
		return 1, nil
	}
	return int(m.Int64) + 1, nil
}

func (r *Repository) InsertSet(ctx context.Context, workoutID, exerciseID string, setNumber int, reps *int, weight *float64, rpe *float64, isFailure bool, notes *string) (*SetOut, error) {
	const q = `
		INSERT INTO workout_sets (workout_id, exercise_id, set_number, reps, weight_kg, rpe, is_failure, notes)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id, workout_id, exercise_id, set_number, reps, weight_kg, rpe, is_failure, notes, created_at`
	var s Set
	err := r.pool.QueryRow(ctx, q, workoutID, exerciseID, setNumber, reps, weight, rpe, isFailure, notes).Scan(
		&s.ID, &s.WorkoutID, &s.ExerciseID, &s.SetNumber, &s.Reps, &s.WeightKg, &s.RPE, &s.IsFailure, &s.Notes, &s.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	var name string
	_ = r.pool.QueryRow(ctx, `SELECT name FROM exercises WHERE id = $1`, exerciseID).Scan(&name)
	return &SetOut{Set: s, ExerciseName: name}, nil
}

func (r *Repository) GetSetForWorkout(ctx context.Context, workoutID, setID string) (*Set, error) {
	const q = `SELECT id, workout_id, exercise_id, set_number, reps, weight_kg, rpe, is_failure, notes, created_at
		FROM workout_sets WHERE id = $1 AND workout_id = $2`
	rows, _ := r.pool.Query(ctx, q, setID, workoutID)
	s, err := pgx.CollectOneRow(rows, pgx.RowToStructByName[Set])
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrSetNotFound
		}
		return nil, err
	}
	return &s, nil
}

func (r *Repository) UpdateSetFull(ctx context.Context, workoutID, setID string, s Set) (*SetOut, error) {
	tag, err := r.pool.Exec(ctx, `
		UPDATE workout_sets SET reps = $1, weight_kg = $2, rpe = $3, is_failure = $4, notes = $5
		WHERE id = $6 AND workout_id = $7`,
		s.Reps, s.WeightKg, s.RPE, s.IsFailure, s.Notes, setID, workoutID)
	if err != nil {
		return nil, err
	}
	if tag.RowsAffected() == 0 {
		return nil, ErrSetNotFound
	}
	const q = `
		SELECT ws.id, ws.workout_id, ws.exercise_id, ws.set_number, ws.reps, ws.weight_kg, ws.rpe, ws.is_failure, ws.notes, ws.created_at,
			e.name AS exercise_name
		FROM workout_sets ws JOIN exercises e ON e.id = ws.exercise_id
		WHERE ws.id = $1 AND ws.workout_id = $2`
	rows, _ := r.pool.Query(ctx, q, setID, workoutID)
	row, err := pgx.CollectOneRow(rows, pgx.RowToStructByName[setRow])
	if err != nil {
		return nil, err
	}
	return &SetOut{Set: row.Set, ExerciseName: row.ExerciseName}, nil
}

func (r *Repository) DeleteSet(ctx context.Context, workoutID, setID string) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM workout_sets WHERE id = $1 AND workout_id = $2`, setID, workoutID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrSetNotFound
	}
	return nil
}

func (r *Repository) ListSetsRaw(ctx context.Context, workoutID string) ([]Set, error) {
	const q = `SELECT id, workout_id, exercise_id, set_number, reps, weight_kg, rpe, is_failure, notes, created_at
		FROM workout_sets WHERE workout_id = $1`
	rows, err := r.pool.Query(ctx, q, workoutID)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, pgx.RowToStructByName[Set])
}

// HistoricalMaxE1RMPerExercise returns best Brzycki e1RM per exercise_id from completed workouts excluding excludeWorkoutID.
func (r *Repository) HistoricalMaxE1RMPerExercise(ctx context.Context, userID, excludeWorkoutID string, estimate func(weight float64, reps int) float64) (map[string]float64, error) {
	const q = `
		SELECT ws.exercise_id, ws.weight_kg, ws.reps
		FROM workout_sets ws
		INNER JOIN workouts w ON w.id = ws.workout_id
		WHERE w.user_id = $1 AND w.completed_at IS NOT NULL AND w.id <> $2::uuid`
	rows, err := r.pool.Query(ctx, q, userID, excludeWorkoutID)
	if err != nil {
		return nil, err
	}
	type pair struct {
		ExID string
		W    *float64
		R    *int
	}
	list, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (pair, error) {
		var p pair
		err := row.Scan(&p.ExID, &p.W, &p.R)
		return p, err
	})
	if err != nil {
		return nil, err
	}
	best := make(map[string]float64)
	for _, p := range list {
		if p.W == nil || p.R == nil || *p.R <= 0 {
			continue
		}
		e := estimate(*p.W, *p.R)
		if e <= 0 {
			continue
		}
		if e > best[p.ExID] {
			best[p.ExID] = e
		}
	}
	return best, nil
}

// HistoricalMaxE1RMPerExerciseSince returns best Brzycki e1RM per exercise_id from completed workouts
// excluding excludeWorkoutID and only including workouts completed at or after "since".
func (r *Repository) HistoricalMaxE1RMPerExerciseSince(ctx context.Context, userID, excludeWorkoutID string, since time.Time, estimate func(weight float64, reps int) float64) (map[string]float64, error) {
	const q = `
		SELECT ws.exercise_id, ws.weight_kg, ws.reps
		FROM workout_sets ws
		INNER JOIN workouts w ON w.id = ws.workout_id
		WHERE w.user_id = $1
		  AND w.completed_at IS NOT NULL
		  AND w.completed_at >= $3
		  AND w.id <> $2::uuid`
	rows, err := r.pool.Query(ctx, q, userID, excludeWorkoutID, since)
	if err != nil {
		return nil, err
	}
	type pair struct {
		ExID string
		W    *float64
		R    *int
	}
	list, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (pair, error) {
		var p pair
		err := row.Scan(&p.ExID, &p.W, &p.R)
		return p, err
	})
	if err != nil {
		return nil, err
	}
	best := make(map[string]float64)
	for _, p := range list {
		if p.W == nil || p.R == nil || *p.R <= 0 {
			continue
		}
		e := estimate(*p.W, *p.R)
		if e <= 0 {
			continue
		}
		if e > best[p.ExID] {
			best[p.ExID] = e
		}
	}
	return best, nil
}

// HistoricalLatestE1RMPerExercise returns the best Brzycki e1RM per exercise_id
// from the most recent completed workout where that exercise appears (excluding excludeWorkoutID).
// If an exercise has multiple sets in that most recent workout, we take the max e1RM among those sets.
func (r *Repository) HistoricalLatestE1RMPerExercise(ctx context.Context, userID, excludeWorkoutID string, estimate func(weight float64, reps int) float64) (map[string]float64, error) {
	const q = `
		SELECT ws.workout_id, w.completed_at, ws.exercise_id, ws.weight_kg, ws.reps
		FROM workout_sets ws
		INNER JOIN workouts w ON w.id = ws.workout_id
		WHERE w.user_id = $1
		  AND w.completed_at IS NOT NULL
		  AND w.id <> $2::uuid
		  AND ws.reps IS NOT NULL AND ws.reps > 0
		  AND ws.weight_kg IS NOT NULL AND ws.weight_kg > 0
		ORDER BY w.completed_at DESC`
	rows, err := r.pool.Query(ctx, q, userID, excludeWorkoutID)
	if err != nil {
		return nil, err
	}
	type rowT struct {
		WorkoutID string
		Completed time.Time
		ExID      string
		W         float64
		R         int
	}
	list, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (rowT, error) {
		var x rowT
		err := row.Scan(&x.WorkoutID, &x.Completed, &x.ExID, &x.W, &x.R)
		return x, err
	})
	if err != nil {
		return nil, err
	}

	best := make(map[string]float64)
	latestWorkout := make(map[string]string) // exercise_id -> workout_id
	for _, p := range list {
		e := estimate(p.W, p.R)
		if e <= 0 {
			continue
		}
		wid, ok := latestWorkout[p.ExID]
		if !ok {
			latestWorkout[p.ExID] = p.WorkoutID
			best[p.ExID] = e
			continue
		}
		if wid == p.WorkoutID && e > best[p.ExID] {
			best[p.ExID] = e
		}
	}
	return best, nil
}

// ListExerciseNamesFromCompletedWorkouts returns distinct exercise names the user
// has logged with countable load (reps + weight) in finished sessions.
func (r *Repository) ListExerciseNamesFromCompletedWorkouts(ctx context.Context, userID string) ([]string, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT DISTINCT e.name
		FROM workout_sets ws
		JOIN workouts w ON w.id = ws.workout_id
		JOIN exercises e ON e.id = ws.exercise_id
		WHERE w.user_id = $1
		  AND w.completed_at IS NOT NULL
		  AND ws.reps IS NOT NULL AND ws.reps > 0
		  AND ws.weight_kg IS NOT NULL AND ws.weight_kg > 0
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var names []string
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			return nil, err
		}
		names = append(names, name)
	}
	return names, rows.Err()
}

func (r *Repository) FinishWorkoutTx(ctx context.Context, tx pgx.Tx, workoutID string, completedAt time.Time, notes *string, volume float64, durationSec int, stats FinishStats) error {
	b, err := json.Marshal(stats)
	if err != nil {
		return err
	}
	tag, err := tx.Exec(ctx, `
		UPDATE workouts SET
			completed_at = $1,
			notes = COALESCE($2, notes),
			total_volume_kg = $3,
			duration_seconds = $4,
			stats = $5::jsonb
		WHERE id = $6 AND completed_at IS NULL
	`, completedAt, notes, volume, durationSec, b, workoutID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrAlreadyFinished
	}
	return nil
}

func (r *Repository) InsertStrengthEloHistoryTx(ctx context.Context, tx pgx.Tx, userID, workoutID string, beforeElo, afterElo, delta int, bw *float64, sessionScore float64, meta json.RawMessage) error {
	_, err := tx.Exec(ctx, `
		INSERT INTO strength_elo_history (user_id, workout_id, elo_before, elo_after, delta, bodyweight_kg, session_score, meta)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb)`,
		userID, workoutID, beforeElo, afterElo, delta, bw, sessionScore, meta)
	return err
}

func (r *Repository) SumEloDelta30dTx(ctx context.Context, tx pgx.Tx, userID string) (int, error) {
	var sum int64
	err := tx.QueryRow(ctx, `
		SELECT COALESCE(SUM(delta), 0)::bigint FROM strength_elo_history
		WHERE user_id = $1 AND created_at >= NOW() - INTERVAL '30 days'`,
		userID).Scan(&sum)
	if err != nil {
		return 0, err
	}
	return int(sum), nil
}

func (r *Repository) SumEloDelta30d(ctx context.Context, userID string) (int, error) {
	var sum int64
	err := r.pool.QueryRow(ctx, `
		SELECT COALESCE(SUM(delta), 0)::bigint FROM strength_elo_history
		WHERE user_id = $1 AND created_at >= NOW() - INTERVAL '30 days'`,
		userID).Scan(&sum)
	if err != nil {
		return 0, err
	}
	return int(sum), nil
}
