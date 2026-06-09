package analytics

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct {
	pool *pgxpool.Pool
}

func NewRepository(pool *pgxpool.Pool) *Repository {
	return &Repository{pool: pool}
}

// SumVolumeCompletedSince sums total_volume_kg for finished workouts since t (UTC).
func (r *Repository) SumVolumeCompletedSince(ctx context.Context, userID string, since time.Time) (float64, error) {
	var sum float64
	err := r.pool.QueryRow(ctx, `
		SELECT COALESCE(SUM(total_volume_kg), 0)::float8
		FROM workouts
		WHERE user_id = $1 AND completed_at IS NOT NULL AND completed_at >= $2`,
		userID, since,
	).Scan(&sum)
	if err != nil {
		return 0, err
	}
	return sum, nil
}

type completedWorkoutRow struct {
	ID              string
	CompletedAt     time.Time
	TotalVolumeKg   *float64
	DurationSeconds *int
	Stats           []byte
	RoutineID       *string
	Name            *string
}

func scanCompletedWorkoutRow(rows interface{ Scan(dest ...any) error }) (completedWorkoutRow, error) {
	var row completedWorkoutRow
	var rid, wname sql.NullString
	if err := rows.Scan(&row.ID, &row.CompletedAt, &row.TotalVolumeKg, &row.DurationSeconds, &row.Stats, &rid, &wname); err != nil {
		return row, err
	}
	row.RoutineID = nullStringToPtr(rid)
	row.Name = nullStringToPtr(wname)
	return row, nil
}

func nullStringToPtr(ns sql.NullString) *string {
	if !ns.Valid {
		return nil
	}
	s := strings.TrimSpace(ns.String)
	if s == "" {
		return nil
	}
	return &s
}

func (r *Repository) ListCompletedWorkoutsRecent(ctx context.Context, userID string, limit int) ([]completedWorkoutRow, error) {
	if limit < 1 {
		limit = 20
	}
	if limit > 60 {
		limit = 60
	}
	rows, err := r.pool.Query(ctx, `
		SELECT id::text, completed_at, total_volume_kg, duration_seconds, COALESCE(stats, '{}'::jsonb),
		       routine_id::text, name
		FROM workouts
		WHERE user_id = $1 AND completed_at IS NOT NULL
		ORDER BY completed_at DESC
		LIMIT $2`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []completedWorkoutRow
	for rows.Next() {
		row, err := scanCompletedWorkoutRow(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, row)
	}
	return out, rows.Err()
}

// ProgressionSetRow is one logged set on a recently completed workout (for e1RM aggregation).
type ProgressionSetRow struct {
	WorkoutID    string
	CompletedAt  time.Time
	ExerciseID   string
	ExerciseName string
	Reps         *int
	WeightKg     *float64
}

// ListRecentCompletedWorkoutSetsForProgression returns all sets for the N most recent completed
// workouts, ordered by workout completed_at ascending then exercise/set (same Brzycki inputs as finish).
func (r *Repository) ListRecentCompletedWorkoutSetsForProgression(ctx context.Context, userID string, workoutLimit int) ([]ProgressionSetRow, error) {
	if workoutLimit < 1 {
		workoutLimit = 20
	}
	if workoutLimit > 60 {
		workoutLimit = 60
	}
	rows, err := r.pool.Query(ctx, `
		WITH recent AS (
			SELECT id, completed_at
			FROM workouts
			WHERE user_id = $1 AND completed_at IS NOT NULL
			ORDER BY completed_at DESC
			LIMIT $2
		)
		SELECT w.id::text, w.completed_at, ws.exercise_id::text, e.name,
			ws.reps, ws.weight_kg
		FROM recent w
		INNER JOIN workout_sets ws ON ws.workout_id = w.id
		INNER JOIN exercises e ON e.id = ws.exercise_id
		ORDER BY w.completed_at ASC, ws.exercise_id::text, ws.set_number`,
		userID, workoutLimit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []ProgressionSetRow
	for rows.Next() {
		var row ProgressionSetRow
		var reps pgtype.Int4
		var wkg pgtype.Float8
		if err := rows.Scan(&row.WorkoutID, &row.CompletedAt, &row.ExerciseID, &row.ExerciseName, &reps, &wkg); err != nil {
			return nil, err
		}
		if reps.Valid {
			v := int(reps.Int32)
			row.Reps = &v
		}
		if wkg.Valid {
			v := wkg.Float64
			row.WeightKg = &v
		}
		out = append(out, row)
	}
	return out, rows.Err()
}

// ListRecentCompletedWorkoutSetsForProgressionByRoutine is like ListRecentCompletedWorkoutSetsForProgression
// but only includes completed workouts logged against the given routine_id.
func (r *Repository) ListRecentCompletedWorkoutSetsForProgressionByRoutine(ctx context.Context, userID, routineID string, workoutLimit int) ([]ProgressionSetRow, error) {
	if workoutLimit < 1 {
		workoutLimit = 20
	}
	if workoutLimit > 60 {
		workoutLimit = 60
	}
	rows, err := r.pool.Query(ctx, `
		WITH recent AS (
			SELECT id, completed_at
			FROM workouts
			WHERE user_id = $1
			  AND completed_at IS NOT NULL
			  AND routine_id = $3::uuid
			ORDER BY completed_at DESC
			LIMIT $2
		)
		SELECT w.id::text, w.completed_at, ws.exercise_id::text, e.name,
			ws.reps, ws.weight_kg
		FROM recent w
		INNER JOIN workout_sets ws ON ws.workout_id = w.id
		INNER JOIN exercises e ON e.id = ws.exercise_id
		ORDER BY w.completed_at ASC, ws.exercise_id::text, ws.set_number`,
		userID, workoutLimit, routineID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []ProgressionSetRow
	for rows.Next() {
		var row ProgressionSetRow
		var reps pgtype.Int4
		var wkg pgtype.Float8
		if err := rows.Scan(&row.WorkoutID, &row.CompletedAt, &row.ExerciseID, &row.ExerciseName, &reps, &wkg); err != nil {
			return nil, err
		}
		if reps.Valid {
			v := int(reps.Int32)
			row.Reps = &v
		}
		if wkg.Valid {
			v := wkg.Float64
			row.WeightKg = &v
		}
		out = append(out, row)
	}
	return out, rows.Err()
}

// GetPreviousMatchingCompleted returns the most recent completed workout strictly before `before`,
// matching the latest session's routine_id when set; otherwise matching ad-hoc workouts by name
// (routine_id IS NULL). Returns (nil, nil) when no match exists.
func (r *Repository) GetPreviousMatchingCompleted(ctx context.Context, userID string, before time.Time, routineID *string, workoutName *string) (*completedWorkoutRow, error) {
	if rid, ok := routineKey(routineID); ok {
		row, err := r.queryOneCompletedBefore(ctx, `
			SELECT id::text, completed_at, total_volume_kg, duration_seconds, COALESCE(stats, '{}'::jsonb),
			       routine_id::text, name
			FROM workouts
			WHERE user_id = $1 AND completed_at IS NOT NULL AND completed_at < $2
			  AND routine_id = $3::uuid
			ORDER BY completed_at DESC
			LIMIT 1`, userID, before, rid)
		return row, err
	}
	nk, ok := normalizedWorkoutNameKey(workoutName)
	if !ok {
		return nil, nil
	}
	row, err := r.queryOneCompletedBefore(ctx, `
		SELECT id::text, completed_at, total_volume_kg, duration_seconds, COALESCE(stats, '{}'::jsonb),
		       routine_id::text, name
		FROM workouts
		WHERE user_id = $1 AND completed_at IS NOT NULL AND completed_at < $2
		  AND routine_id IS NULL
		  AND LOWER(TRIM(COALESCE(name, ''))) = $3
		ORDER BY completed_at DESC
		LIMIT 1`, userID, before, nk)
	return row, err
}

func routineKey(r *string) (string, bool) {
	if r == nil {
		return "", false
	}
	s := strings.TrimSpace(*r)
	if s == "" {
		return "", false
	}
	return s, true
}

func normalizedWorkoutNameKey(n *string) (string, bool) {
	if n == nil {
		return "", false
	}
	s := strings.TrimSpace(strings.ToLower(*n))
	if s == "" {
		return "", false
	}
	return s, true
}

func (r *Repository) queryOneCompletedBefore(ctx context.Context, query string, args ...any) (*completedWorkoutRow, error) {
	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	if !rows.Next() {
		if err := rows.Err(); err != nil {
			return nil, err
		}
		return nil, nil
	}
	row, err := scanCompletedWorkoutRow(rows)
	if err != nil {
		return nil, err
	}
	return &row, rows.Err()
}

// CountCompletedWorkouts returns all-time finished workout count for a user.
func (r *Repository) CountCompletedWorkouts(ctx context.Context, userID string) (int, error) {
	var n int
	err := r.pool.QueryRow(ctx, `
		SELECT COUNT(*)::int FROM workouts
		WHERE user_id = $1 AND completed_at IS NOT NULL`,
		userID,
	).Scan(&n)
	return n, err
}

// ArchetypeSetRow is one set with muscle group for gym archetype scoring.
type ArchetypeSetRow struct {
	WorkoutID    string
	CompletedAt  time.Time
	ExerciseName string
	MuscleGroup  string
	Reps         int
	WeightKg     float64
}

// ListArchetypeSets returns sets (with muscle groups) for the user's N most recent completed workouts.
func (r *Repository) ListArchetypeSets(ctx context.Context, userID string, workoutLimit int) ([]ArchetypeSetRow, error) {
	if workoutLimit < 1 {
		workoutLimit = 36
	}
	if workoutLimit > 60 {
		workoutLimit = 60
	}
	rows, err := r.pool.Query(ctx, `
		WITH recent AS (
			SELECT id, completed_at
			FROM workouts
			WHERE user_id = $1 AND completed_at IS NOT NULL
			ORDER BY completed_at DESC
			LIMIT $2
		)
		SELECT w.id::text, w.completed_at, e.name, COALESCE(e.muscle_group, ''),
			ws.reps::int, ws.weight_kg::float8
		FROM recent w
		INNER JOIN workout_sets ws ON ws.workout_id = w.id
		INNER JOIN exercises e ON e.id = ws.exercise_id
		WHERE ws.reps IS NOT NULL AND ws.weight_kg IS NOT NULL
		  AND ws.reps > 0 AND ws.weight_kg > 0
		ORDER BY w.completed_at ASC, ws.exercise_id::text, ws.set_number`,
		userID, workoutLimit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []ArchetypeSetRow
	for rows.Next() {
		var row ArchetypeSetRow
		if err := rows.Scan(&row.WorkoutID, &row.CompletedAt, &row.ExerciseName, &row.MuscleGroup, &row.Reps, &row.WeightKg); err != nil {
			return nil, err
		}
		out = append(out, row)
	}
	return out, rows.Err()
}

func (r *Repository) CountCompletedSince(ctx context.Context, userID string, since time.Time) (int, error) {
	var n int
	err := r.pool.QueryRow(ctx, `
		SELECT COUNT(*)::int FROM workouts
		WHERE user_id = $1 AND completed_at IS NOT NULL AND completed_at >= $2`,
		userID, since,
	).Scan(&n)
	return n, err
}

type eloHistRow struct {
	EloAfter  int
	Delta     int
	CreatedAt time.Time
}

func (r *Repository) ListEloHistoryRecent(ctx context.Context, userID string, limit int) ([]eloHistRow, error) {
	if limit < 1 {
		limit = 20
	}
	if limit > 60 {
		limit = 60
	}
	rows, err := r.pool.Query(ctx, `
		SELECT elo_after, delta, created_at
		FROM strength_elo_history
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT $2`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []eloHistRow
	for rows.Next() {
		var row eloHistRow
		if err := rows.Scan(&row.EloAfter, &row.Delta, &row.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, row)
	}
	return out, rows.Err()
}

func (r *Repository) SumEloDeltaSince(ctx context.Context, userID string, since time.Time) (int, error) {
	var sum int64
	err := r.pool.QueryRow(ctx, `
		SELECT COALESCE(SUM(delta), 0)::bigint
		FROM strength_elo_history
		WHERE user_id = $1 AND created_at >= $2`,
		userID, since,
	).Scan(&sum)
	if err != nil {
		return 0, err
	}
	return int(sum), nil
}

// ListDistinctCompletionDatesUTC returns unique UTC calendar dates with a completed workout, newest first.
func (r *Repository) ListDistinctCompletionDatesUTC(ctx context.Context, userID string, limit int) ([]time.Time, error) {
	if limit < 1 {
		limit = 90
	}
	if limit > 400 {
		limit = 400
	}
	rows, err := r.pool.Query(ctx, `
		SELECT DISTINCT ((completed_at AT TIME ZONE 'UTC'))::date AS d
		FROM workouts
		WHERE user_id = $1 AND completed_at IS NOT NULL
		ORDER BY d DESC
		LIMIT $2`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []time.Time
	for rows.Next() {
		var d time.Time
		if err := rows.Scan(&d); err != nil {
			return nil, err
		}
		out = append(out, d.UTC().Truncate(24*time.Hour))
	}
	return out, rows.Err()
}

// ExerciseDetailRow is one set row for a single exercise across recent completed workouts.
type ExerciseDetailRow struct {
	WorkoutID    string
	CompletedAt  time.Time
	Stats        []byte
	ExerciseID   string
	ExerciseName string
	Reps         *int
	WeightKg     *float64
	SetNumber    int
}

// ListExerciseDetailRows returns sets for one exercise across the user's recent completed workouts.
func (r *Repository) ListExerciseDetailRows(ctx context.Context, userID, exerciseID string, workoutLimit int) ([]ExerciseDetailRow, error) {
	if workoutLimit < 1 {
		workoutLimit = 40
	}
	if workoutLimit > 80 {
		workoutLimit = 80
	}
	rows, err := r.pool.Query(ctx, `
		WITH recent AS (
			SELECT id, completed_at, COALESCE(stats, '{}'::jsonb) AS stats
			FROM workouts
			WHERE user_id = $1 AND completed_at IS NOT NULL
			ORDER BY completed_at DESC
			LIMIT $3
		)
		SELECT w.id::text, w.completed_at, w.stats, ws.exercise_id::text, e.name,
			ws.reps, ws.weight_kg, ws.set_number
		FROM recent w
		INNER JOIN workout_sets ws ON ws.workout_id = w.id AND ws.exercise_id = $2::uuid
		INNER JOIN exercises e ON e.id = ws.exercise_id
		ORDER BY w.completed_at ASC, ws.set_number ASC`,
		userID, exerciseID, workoutLimit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []ExerciseDetailRow
	for rows.Next() {
		var row ExerciseDetailRow
		var reps pgtype.Int4
		var wkg pgtype.Float8
		if err := rows.Scan(&row.WorkoutID, &row.CompletedAt, &row.Stats, &row.ExerciseID, &row.ExerciseName, &reps, &wkg, &row.SetNumber); err != nil {
			return nil, err
		}
		if reps.Valid {
			v := int(reps.Int32)
			row.Reps = &v
		}
		if wkg.Valid {
			v := wkg.Float64
			row.WeightKg = &v
		}
		out = append(out, row)
	}
	return out, rows.Err()
}

// sqlBrzyckiE1 matches internal/strength.Estimate1RMBrzycki for reps > 0, weight > 0 (reps ≥ 37 → weight only).
const sqlBrzyckiE1 = `(CASE WHEN ws.reps >= 37 THEN ws.weight_kg::float8 ELSE ws.weight_kg::float8 * 36.0 / (37.0 - ws.reps::float8) END)`

// LifetimeBestSet is the user's best Brzycki e1RM set for an exercise across all completed workouts.
type LifetimeBestSet struct {
	ExerciseID   string
	ExerciseName string
	SetID        string
	WorkoutID    string
	CompletedAt  time.Time
	Reps         int
	WeightKg     float64
	BestE1RMKg   float64
}

// GetLifetimeBestSetForExercise returns the best single set by Brzycki e1RM for this user+exercise
// across every completed workout (no arbitrary workout cap).
func (r *Repository) GetLifetimeBestSetForExercise(ctx context.Context, userID, exerciseID string) (*LifetimeBestSet, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT ws.exercise_id::text, e.name, ws.id::text, w.id::text, w.completed_at,
			ws.reps::int, ws.weight_kg::float8, `+sqlBrzyckiE1+` AS e1rm
		FROM workout_sets ws
		INNER JOIN workouts w ON w.id = ws.workout_id
		INNER JOIN exercises e ON e.id = ws.exercise_id
		WHERE w.user_id = $1::uuid
		  AND ws.exercise_id = $2::uuid
		  AND w.completed_at IS NOT NULL
		  AND ws.reps IS NOT NULL AND ws.weight_kg IS NOT NULL
		  AND ws.reps > 0 AND ws.weight_kg > 0
		ORDER BY e1rm DESC NULLS LAST
		LIMIT 1`, userID, exerciseID)
	var out LifetimeBestSet
	err := row.Scan(&out.ExerciseID, &out.ExerciseName, &out.SetID, &out.WorkoutID, &out.CompletedAt,
		&out.Reps, &out.WeightKg, &out.BestE1RMKg)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &out, nil
}

// ListLifetimeBestSetPerExercise returns, for each exercise the user has ever logged on a completed workout,
// the single set with highest Brzycki e1RM (user lifetime PR per lift).
func (r *Repository) ListLifetimeBestSetPerExercise(ctx context.Context, userID string) ([]LifetimeBestSet, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT DISTINCT ON (ws.exercise_id)
			ws.exercise_id::text, e.name, ws.id::text, w.id::text, w.completed_at,
			ws.reps::int, ws.weight_kg::float8, `+sqlBrzyckiE1+` AS e1rm
		FROM workout_sets ws
		INNER JOIN workouts w ON w.id = ws.workout_id
		INNER JOIN exercises e ON e.id = ws.exercise_id
		WHERE w.user_id = $1::uuid
		  AND w.completed_at IS NOT NULL
		  AND ws.reps IS NOT NULL AND ws.weight_kg IS NOT NULL
		  AND ws.reps > 0 AND ws.weight_kg > 0
		ORDER BY ws.exercise_id, e1rm DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []LifetimeBestSet
	for rows.Next() {
		var lb LifetimeBestSet
		if err := rows.Scan(&lb.ExerciseID, &lb.ExerciseName, &lb.SetID, &lb.WorkoutID, &lb.CompletedAt,
			&lb.Reps, &lb.WeightKg, &lb.BestE1RMKg); err != nil {
			return nil, err
		}
		out = append(out, lb)
	}
	return out, rows.Err()
}
