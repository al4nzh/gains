package ai

import (
	"encoding/json"
	"time"
)

const (
	InsightTypePostWorkout      = "post_workout"
	InsightTypeWeeklySummary    = "weekly_summary"
	InsightTypePatternDetection = "pattern_detection"
)

type Insight struct {
	ID            string          `json:"id"            db:"id"`
	UserID        string          `json:"user_id"       db:"user_id"`
	WorkoutID     *string         `json:"workout_id,omitempty" db:"workout_id"`
	InsightType   string          `json:"insight_type"  db:"insight_type"`
	GeneratedText string          `json:"generated_text" db:"generated_text"`
	Metrics       json.RawMessage `json:"metrics,omitempty" db:"metrics"`
	Model         *string         `json:"model,omitempty" db:"model"`
	CreatedAt     time.Time       `json:"created_at"    db:"created_at"`
}
