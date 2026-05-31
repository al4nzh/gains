package physique

import "time"

type Scan struct {
	ID                  string    `json:"id"`
	UserID              string    `json:"user_id"`
	EstimatedBodyFatPct int       `json:"estimated_body_fat_pct"`
	Confidence          string    `json:"confidence"`
	Summary             string    `json:"summary"`
	Reasoning           string    `json:"reasoning"`
	CreatedAt           time.Time `json:"created_at"`
}

type EstimateResult struct {
	EstimatedBodyFatPct int    `json:"estimated_body_fat_pct"`
	Confidence          string `json:"confidence"`
	Summary             string `json:"summary"`
	Reasoning           string `json:"reasoning"`
}
