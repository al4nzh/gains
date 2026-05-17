package physique

import "time"

type Scan struct {
	ID                   string    `json:"id"`
	UserID               string    `json:"user_id"`
	ImageURL             string    `json:"image_url"`
	EstimatedBodyFatPct  int       `json:"estimated_body_fat_pct"`
	Confidence           string    `json:"confidence"`
	CreatedAt            time.Time `json:"created_at"`
}

type EstimateResult struct {
	EstimatedBodyFatPct int    `json:"estimated_body_fat_pct"`
	Confidence          string `json:"confidence"`
}
