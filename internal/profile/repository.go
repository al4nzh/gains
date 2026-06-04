package profile

import (
	"context"
	"errors"

	"gainsai/internal/strength"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct {
	pool *pgxpool.Pool
}

func NewRepository(pool *pgxpool.Pool) *Repository {
	return &Repository{pool: pool}
}

const profileColumns = `user_id, age, weight_kg, height_cm, gender, fitness_goal, training_experience, preferred_split, injury_notes, activity_level, strength_elo, strength_elo_rank, strength_elo_change_30d, last_strength_elo_update, created_at, updated_at`

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
			fitness_goal, training_experience, preferred_split, injury_notes, activity_level
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		ON CONFLICT (user_id) DO UPDATE SET
			age = EXCLUDED.age,
			weight_kg = EXCLUDED.weight_kg,
			height_cm = EXCLUDED.height_cm,
			gender = EXCLUDED.gender,
			fitness_goal = EXCLUDED.fitness_goal,
			training_experience = EXCLUDED.training_experience,
			preferred_split = EXCLUDED.preferred_split,
			injury_notes = EXCLUDED.injury_notes,
			activity_level = EXCLUDED.activity_level,
			updated_at = NOW()
	`, p.UserID, p.Age, p.WeightKg, p.HeightCm, p.Gender, p.FitnessGoal, p.TrainingExperience, p.PreferredSplit, p.InjuryNotes, p.ActivityLevel)
	return err
}

// UpsertStrengthElo updates Elo fields, creating a minimal profiles row if needed.
func (r *Repository) UpsertStrengthElo(ctx context.Context, userID string, elo int, rank string, change30d int) error {
	_, err := r.pool.Exec(ctx, `
		INSERT INTO profiles (user_id, strength_elo, strength_elo_rank, strength_elo_change_30d, last_strength_elo_update)
		VALUES ($1, $2, $3, $4, NOW())
		ON CONFLICT (user_id) DO UPDATE SET
			strength_elo = EXCLUDED.strength_elo,
			strength_elo_rank = EXCLUDED.strength_elo_rank,
			strength_elo_change_30d = EXCLUDED.strength_elo_change_30d,
			last_strength_elo_update = NOW(),
			updated_at = NOW()
	`, userID, elo, rank, change30d)
	return err
}

// UpsertStrengthEloTx is like UpsertStrengthElo but uses an existing transaction.
func (r *Repository) UpsertStrengthEloTx(ctx context.Context, tx pgx.Tx, userID string, elo int, rank string, change30d int) error {
	_, err := tx.Exec(ctx, `
		INSERT INTO profiles (user_id, strength_elo, strength_elo_rank, strength_elo_change_30d, last_strength_elo_update)
		VALUES ($1, $2, $3, $4, NOW())
		ON CONFLICT (user_id) DO UPDATE SET
			strength_elo = EXCLUDED.strength_elo,
			strength_elo_rank = EXCLUDED.strength_elo_rank,
			strength_elo_change_30d = EXCLUDED.strength_elo_change_30d,
			last_strength_elo_update = NOW(),
			updated_at = NOW()
	`, userID, elo, rank, change30d)
	return err
}

// StrengthEloPercentile returns how many percent of rated lifters have strictly lower Elo (0–100).
// When peerGender is female or male, only profiles with that gender are counted; otherwise all rated profiles.
// ok is false when there are not enough rated profiles for a meaningful comparison.
func (r *Repository) StrengthEloPercentile(ctx context.Context, elo int, peerGender *string) (percentile int, ok bool, err error) {
	var below, total int
	if peerGender != nil && (*peerGender == GenderFemale || *peerGender == GenderMale) {
		err = r.pool.QueryRow(ctx, `
			SELECT
				COUNT(*) FILTER (WHERE strength_elo IS NOT NULL AND strength_elo < $1),
				COUNT(*) FILTER (WHERE strength_elo IS NOT NULL)
			FROM profiles
			WHERE gender = $2
		`, elo, *peerGender).Scan(&below, &total)
	} else {
		err = r.pool.QueryRow(ctx, `
			SELECT
				COUNT(*) FILTER (WHERE strength_elo IS NOT NULL AND strength_elo < $1),
				COUNT(*) FILTER (WHERE strength_elo IS NOT NULL)
			FROM profiles
		`, elo).Scan(&below, &total)
	}
	if err != nil {
		return 0, false, err
	}
	p, ok := strength.PercentileFromCounts(below, total)
	return p, ok, nil
}
