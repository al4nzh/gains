package profile

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

const profileColumns = `user_id, age, weight_kg, height_cm, gender, fitness_goal, training_experience, preferred_split, injury_notes, created_at, updated_at`

// GetByUserID returns the row for user_id, or an in-memory empty profile (same user_id)
// when no row exists yet.
func (r *Repository) GetByUserID(ctx context.Context, userID string) (*Profile, error) {
	rows, _ := r.pool.Query(ctx, `SELECT `+profileColumns+` FROM profiles WHERE user_id = $1`, userID)
	p, err := pgx.CollectOneRow(rows, pgx.RowToStructByName[Profile])
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return &Profile{UserID: userID}, nil
		}
		return nil, err
	}
	return &p, nil
}

// Upsert inserts or replaces profile fields for the given user.
func (r *Repository) Upsert(ctx context.Context, p *Profile) error {
	_, err := r.pool.Exec(ctx, `
		INSERT INTO profiles (
			user_id, age, weight_kg, height_cm, gender,
			fitness_goal, training_experience, preferred_split, injury_notes
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		ON CONFLICT (user_id) DO UPDATE SET
			age = EXCLUDED.age,
			weight_kg = EXCLUDED.weight_kg,
			height_cm = EXCLUDED.height_cm,
			gender = EXCLUDED.gender,
			fitness_goal = EXCLUDED.fitness_goal,
			training_experience = EXCLUDED.training_experience,
			preferred_split = EXCLUDED.preferred_split,
			injury_notes = EXCLUDED.injury_notes,
			updated_at = NOW()
	`, p.UserID, p.Age, p.WeightKg, p.HeightCm, p.Gender, p.FitnessGoal, p.TrainingExperience, p.PreferredSplit, p.InjuryNotes)
	return err
}
