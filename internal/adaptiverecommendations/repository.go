package adaptiverecommendations

import (
	"context"
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

// VolumeByMuscle returns total volume (kg) per muscle_group for completed workouts in [since, until).
func (r *Repository) VolumeByMuscle(ctx context.Context, userID string, since, until time.Time) (map[string]float64, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT COALESCE(e.muscle_group, ''), COALESCE(SUM(ws.reps * ws.weight_kg), 0)::float8
		FROM workout_sets ws
		INNER JOIN workouts w ON w.id = ws.workout_id
		INNER JOIN exercises e ON e.id = ws.exercise_id
		WHERE w.user_id = $1
		  AND w.completed_at IS NOT NULL
		  AND w.completed_at >= $2
		  AND w.completed_at < $3
		  AND ws.reps IS NOT NULL AND ws.reps > 0
		  AND ws.weight_kg IS NOT NULL AND ws.weight_kg > 0
		GROUP BY e.muscle_group`,
		userID, since, until)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[string]float64{}
	for rows.Next() {
		var mg string
		var vol float64
		if err := rows.Scan(&mg, &vol); err != nil {
			return nil, err
		}
		out[mg] = roundVol(vol)
	}
	return out, rows.Err()
}

// VolumeByMuscleForRoutine returns volume per muscle_group from completed workouts
// logged with the given routine_id in [since, until).
func (r *Repository) VolumeByMuscleForRoutine(ctx context.Context, userID, routineID string, since, until time.Time) (map[string]float64, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT COALESCE(e.muscle_group, ''), COALESCE(SUM(ws.reps * ws.weight_kg), 0)::float8
		FROM workout_sets ws
		INNER JOIN workouts w ON w.id = ws.workout_id
		INNER JOIN exercises e ON e.id = ws.exercise_id
		WHERE w.user_id = $1
		  AND w.routine_id = $4::uuid
		  AND w.completed_at IS NOT NULL
		  AND w.completed_at >= $2
		  AND w.completed_at < $3
		  AND ws.reps IS NOT NULL AND ws.reps > 0
		  AND ws.weight_kg IS NOT NULL AND ws.weight_kg > 0
		GROUP BY e.muscle_group`,
		userID, since, until, routineID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[string]float64{}
	for rows.Next() {
		var mg string
		var vol float64
		if err := rows.Scan(&mg, &vol); err != nil {
			return nil, err
		}
		out[mg] = roundVol(vol)
	}
	return out, rows.Err()
}

type workoutAdjustRow struct {
	ID                    string
	AdaptiveAdjustments   []byte
	CompletedAt           *time.Time
	RoutineID             *string
}

func (r *Repository) getWorkoutAdjustRow(ctx context.Context, userID, workoutID string) (*workoutAdjustRow, error) {
	var row workoutAdjustRow
	err := r.pool.QueryRow(ctx, `
		SELECT id::text, COALESCE(adaptive_adjustments, '[]'::jsonb), completed_at, routine_id::text
		FROM workouts
		WHERE id = $1 AND user_id = $2`,
		workoutID, userID).Scan(&row.ID, &row.AdaptiveAdjustments, &row.CompletedAt, &row.RoutineID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrWorkoutNotYours
		}
		return nil, err
	}
	return &row, nil
}

// ListAppliedAdjustments returns session adjustments stored on a workout.
func (r *Repository) ListAppliedAdjustments(ctx context.Context, userID, workoutID string) ([]AppliedAdjustment, error) {
	row, err := r.getWorkoutAdjustRow(ctx, userID, workoutID)
	if err != nil {
		return nil, err
	}
	return ParseAdjustments(row.AdaptiveAdjustments)
}

// AppendAppliedAdjustment adds one adjustment to an active workout.
func (r *Repository) AppendAppliedAdjustment(ctx context.Context, userID, workoutID string, adj AppliedAdjustment) ([]AppliedAdjustment, error) {
	row, err := r.getWorkoutAdjustRow(ctx, userID, workoutID)
	if err != nil {
		return nil, err
	}
	if row.CompletedAt != nil {
		return nil, ErrWorkoutNotActive
	}
	list, err := ParseAdjustments(row.AdaptiveAdjustments)
	if err != nil {
		return nil, err
	}
	for _, a := range list {
		if a.RecommendationID == adj.RecommendationID {
			return nil, ErrAlreadyApplied
		}
	}
	list = append(list, adj)
	b, err := json.Marshal(list)
	if err != nil {
		return nil, err
	}
	tag, err := r.pool.Exec(ctx, `
		UPDATE workouts SET adaptive_adjustments = $1::jsonb
		WHERE id = $2 AND user_id = $3 AND completed_at IS NULL`,
		b, workoutID, userID)
	if err != nil {
		return nil, err
	}
	if tag.RowsAffected() == 0 {
		return nil, ErrWorkoutNotActive
	}
	return list, nil
}
