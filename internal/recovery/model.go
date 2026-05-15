package recovery

import "time"

// Checkin is a daily recovery log: sleep, readiness, calories, protein, optional note.
type Checkin struct {
	ID               string    `json:"id"              db:"id"`
	CheckinDate      time.Time `json:"-"               db:"checkin_date"`
	SleepHours       float64   `json:"sleep_hours"     db:"sleep_hours"`
	EnergyReadiness  int       `json:"energy_readiness" db:"energy_readiness"`
	CaloriesKcal     int       `json:"calories_kcal"   db:"calories_kcal"`
	ProteinG         int       `json:"protein_g"       db:"protein_g"`
	Notes            *string   `json:"notes,omitempty" db:"notes"`
	CreatedAt        time.Time `json:"created_at"      db:"created_at"`
	UpdatedAt        time.Time `json:"updated_at"      db:"updated_at"`
}
