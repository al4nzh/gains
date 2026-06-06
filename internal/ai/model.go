package ai

import (
	"encoding/json"
	"time"
)

const (
	InsightTypePostWorkout      = "post_workout"
	InsightTypeWeeklySummary    = "weekly_summary"
	InsightTypePatternDetection = "pattern_detection"
	InsightTypeWorkoutAnalysis  = "workout_analysis"
)

type Insight struct {
	ID            string          `json:"id"            db:"id"`
	UserID        string          `json:"user_id,omitempty" db:"user_id"`
	WorkoutID     *string         `json:"workout_id,omitempty" db:"workout_id"`
	InsightType   string          `json:"insight_type"  db:"insight_type"`
	Title         string          `json:"title,omitempty" db:"title"`
	GeneratedText string          `json:"generated_text" db:"generated_text"`
	Metrics       json.RawMessage `json:"metrics,omitempty" db:"metrics"`
	Model         *string         `json:"model,omitempty" db:"model"`
	CreatedAt     time.Time       `json:"created_at"    db:"created_at"`
}

// AnalyzeWorkoutRequest is optional JSON body for POST /ai/analyze-workout/:workoutId.
type AnalyzeWorkoutRequest struct {
	UnitSystem string `json:"unit_system,omitempty"`
}

// AnalyzeWorkoutResponse is the JSON body for POST /ai/analyze-workout/:workoutId.
type AnalyzeWorkoutResponse struct {
	ID             string          `json:"id"`
	WorkoutID      string          `json:"workout_id"`
	InsightType    string          `json:"insight_type"`
	Title          string          `json:"title"`
	Message        string          `json:"message"`
	StructuredJSON json.RawMessage `json:"structured_json,omitempty"`
	CreatedAt      time.Time       `json:"created_at"`
}

// InsightListItem is one row for GET /ai/insights (summary field maps stored message text).
type InsightListItem struct {
	ID          string    `json:"id"`
	WorkoutID   *string   `json:"workout_id,omitempty"`
	InsightType string    `json:"insight_type"`
	Title       string    `json:"title"`
	Summary     string    `json:"summary"`
	CreatedAt   time.Time `json:"created_at"`
}
