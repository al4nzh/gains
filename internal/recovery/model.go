package recovery

import "time"

type Checkin struct {
	ID              string    `json:"id"            db:"id"`
	UserID          string    `json:"user_id"       db:"user_id"`
	CheckinDate     time.Time `json:"checkin_date"  db:"checkin_date"`
	SleepScore      *int      `json:"sleep_score,omitempty"      db:"sleep_score"`
	EnergyScore     *int      `json:"energy_score,omitempty"     db:"energy_score"`
	SorenessScore   *int      `json:"soreness_score,omitempty"   db:"soreness_score"`
	StressScore     *int      `json:"stress_score,omitempty"     db:"stress_score"`
	HydrationScore  *int      `json:"hydration_score,omitempty"  db:"hydration_score"`
	CalorieEstimate *int      `json:"calorie_estimate,omitempty" db:"calorie_estimate"`
	ProteinEstimate *int      `json:"protein_estimate,omitempty" db:"protein_estimate"`
	RawVoiceInput   *string   `json:"raw_voice_input,omitempty"  db:"raw_voice_input"`
	CreatedAt       time.Time `json:"created_at"    db:"created_at"`
}
