package recovery

import (
	"context"
	"database/sql"
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

const checkinCols = `id, user_id, checkin_date, sleep_hours, energy_readiness, calories_kcal, protein_g, notes, created_at, updated_at`

type UpsertInput struct {
	UserID          string
	CheckinDate     time.Time
	SleepHours      float64
	EnergyReadiness int
	CaloriesKcal    int
	ProteinG        int
	Notes           *string
}

func (r *Repository) Upsert(ctx context.Context, in UpsertInput) (*Checkin, error) {
	const q = `
		INSERT INTO recovery_checkins (user_id, checkin_date, sleep_hours, energy_readiness, calories_kcal, protein_g, notes)
		VALUES ($1, $2::date, $3, $4, $5, $6, $7)
		ON CONFLICT (user_id, checkin_date) DO UPDATE SET
			sleep_hours = EXCLUDED.sleep_hours,
			energy_readiness = EXCLUDED.energy_readiness,
			calories_kcal = EXCLUDED.calories_kcal,
			protein_g = EXCLUDED.protein_g,
			notes = EXCLUDED.notes,
			updated_at = NOW()
		RETURNING ` + checkinCols
	row := r.pool.QueryRow(ctx, q,
		in.UserID,
		in.CheckinDate.Format("2006-01-02"),
		in.SleepHours,
		in.EnergyReadiness,
		in.CaloriesKcal,
		in.ProteinG,
		in.Notes,
	)
	return scanCheckin(row)
}

func (r *Repository) GetLatest(ctx context.Context, userID string) (*Checkin, error) {
	const q = `SELECT ` + checkinCols + ` FROM recovery_checkins WHERE user_id = $1 ORDER BY checkin_date DESC, updated_at DESC LIMIT 1`
	row := r.pool.QueryRow(ctx, q, userID)
	c, err := scanCheckin(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return c, nil
}

func (r *Repository) ListByDateRange(ctx context.Context, userID string, from, to time.Time) ([]Checkin, error) {
	const q = `
		SELECT ` + checkinCols + `
		FROM recovery_checkins
		WHERE user_id = $1 AND checkin_date >= $2::date AND checkin_date <= $3::date
		ORDER BY checkin_date ASC`
	rows, err := r.pool.Query(ctx, q, userID, from.Format("2006-01-02"), to.Format("2006-01-02"))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Checkin
	for rows.Next() {
		c, err := scanCheckin(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *c)
	}
	return out, rows.Err()
}

func scanCheckin(row interface{ Scan(dest ...any) error }) (*Checkin, error) {
	var (
		c         Checkin
		userID    string
		notesNull sql.NullString
	)
	if err := row.Scan(&c.ID, &userID, &c.CheckinDate, &c.SleepHours, &c.EnergyReadiness, &c.CaloriesKcal, &c.ProteinG, &notesNull, &c.CreatedAt, &c.UpdatedAt); err != nil {
		return nil, err
	}
	if notesNull.Valid {
		s := notesNull.String
		c.Notes = &s
	}
	_ = userID
	return &c, nil
}
