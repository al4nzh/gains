package actionengine

import (
	"encoding/json"
	"time"
)

const (
	StatusPending   = "pending"
	StatusAccepted  = "accepted"
	StatusDismissed = "dismissed"
	StatusApplied   = "applied"
)

const (
	TypeReduceVolume     = "reduce_volume"
	TypeAddRestDay       = "add_rest_day"
	TypeIncreaseRecovery = "increase_recovery"
	TypeImproveNutrition = "improve_nutrition"
	TypeProgressionStall = "progression_stall"
)

type Action struct {
	ID         string          `json:"id"          db:"id"`
	UserID     string          `json:"user_id"     db:"user_id"`
	InsightID  *string         `json:"insight_id,omitempty" db:"insight_id"`
	ActionType string          `json:"action_type" db:"action_type"`
	Payload    json.RawMessage `json:"payload,omitempty" db:"payload"`
	Status     string          `json:"status"      db:"status"`
	CreatedAt  time.Time       `json:"created_at"  db:"created_at"`
	ResolvedAt *time.Time      `json:"resolved_at,omitempty" db:"resolved_at"`
}

func (a *Action) IsResolved() bool {
	return a.Status != StatusPending
}
