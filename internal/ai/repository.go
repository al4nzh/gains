package ai

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ErrDuplicateWorkoutInsight is returned when another request inserted the same workout_id first.
var ErrDuplicateWorkoutInsight = errors.New("duplicate workout insight")

type Repository struct {
	pool *pgxpool.Pool
}

func NewRepository(pool *pgxpool.Pool) *Repository {
	return &Repository{pool: pool}
}

// GetInsightByWorkoutID returns a saved insight for this user+workout, or nil if none.
func (r *Repository) GetInsightByWorkoutID(ctx context.Context, userID, workoutID string) (*Insight, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT id::text, user_id::text, workout_id::text, insight_type,
			COALESCE(NULLIF(TRIM(title), ''), 'Workout analysis'), generated_text,
			COALESCE(metrics, '{}'::jsonb), model, created_at
		FROM ai_insights
		WHERE user_id = $1::uuid AND workout_id = $2::uuid
		LIMIT 1`, userID, workoutID)
	return scanInsight(row)
}

func scanInsight(row interface{ Scan(dest ...any) error }) (*Insight, error) {
	var ins Insight
	var wid sql.NullString
	var modelNull sql.NullString
	if err := row.Scan(&ins.ID, &ins.UserID, &wid, &ins.InsightType, &ins.Title, &ins.GeneratedText, &ins.Metrics, &modelNull, &ins.CreatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	if wid.Valid {
		s := wid.String
		ins.WorkoutID = &s
	}
	if modelNull.Valid {
		s := modelNull.String
		ins.Model = &s
	}
	return &ins, nil
}

// InsertWorkoutInsight inserts one workout-linked insight. Returns ErrDuplicateWorkoutInsight on unique violation.
func (r *Repository) InsertWorkoutInsight(ctx context.Context, userID, workoutID, insightType, title, message string, metrics json.RawMessage, model *string) (*Insight, error) {
	if metrics == nil {
		metrics = json.RawMessage(`{}`)
	}
	row := r.pool.QueryRow(ctx, `
		INSERT INTO ai_insights (user_id, workout_id, insight_type, title, generated_text, metrics, model)
		VALUES ($1::uuid, $2::uuid, $3, $4, $5, $6::jsonb, $7)
		RETURNING id::text, user_id::text, workout_id::text, insight_type,
			COALESCE(NULLIF(TRIM(title), ''), 'Workout analysis'), generated_text,
			COALESCE(metrics, '{}'::jsonb), model, created_at`,
		userID, workoutID, insightType, title, message, metrics, model)
	ins, err := scanInsight(row)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return nil, ErrDuplicateWorkoutInsight
		}
		return nil, err
	}
	return ins, nil
}

// ListInsightsForUser returns saved insights newest first (no OpenAI).
func (r *Repository) ListInsightsForUser(ctx context.Context, userID string, limit int) ([]Insight, error) {
	if limit < 1 {
		limit = 50
	}
	if limit > 100 {
		limit = 100
	}
	rows, err := r.pool.Query(ctx, `
		SELECT id::text, user_id::text, workout_id::text, insight_type,
			COALESCE(NULLIF(TRIM(title), ''), 'Workout analysis'), generated_text,
			COALESCE(metrics, '{}'::jsonb), model, created_at
		FROM ai_insights
		WHERE user_id = $1::uuid
		ORDER BY created_at DESC
		LIMIT $2`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Insight
	for rows.Next() {
		ins, err := scanInsight(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *ins)
	}
	return out, rows.Err()
}
