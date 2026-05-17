package actionengine

import (
	"encoding/json"
	"time"
)

const (
	StatusPending  = "pending"
	StatusAccepted = "accepted"
	StatusRejected = "rejected"
	StatusApplied  = "applied"
	StatusExpired  = "expired"
	// StatusDismissed is legacy; prefer StatusRejected.
	StatusDismissed = "dismissed"
)

const SourceTypeChat = "chat"

const (
	TargetTypeProfile         = "profile"
	TargetTypeRoutine         = "routine"
	TargetTypeRoutineExercise = "routine_exercise"
)

// MVP coach action types (LLM must use these exactly).
const (
	ActionUpdateGoal                    = "update_goal"
	ActionUpdateInjuryNotes             = "update_injury_notes"
	ActionUpdateBodyweight              = "update_bodyweight"
	ActionUpdateHeight                  = "update_height"
	ActionAddExerciseToRoutine          = "add_exercise_to_routine"
	ActionRemoveExerciseFromRoutine     = "remove_exercise_from_routine"
	ActionReplaceExerciseInRoutine      = "replace_exercise_in_routine"
	ActionUpdateRoutineExerciseSets     = "update_routine_exercise_sets"
	ActionUpdateRoutineExerciseRepRange = "update_routine_exercise_rep_range"
	ActionUpdateRoutineExerciseRest     = "update_routine_exercise_rest_seconds"
	ActionRenameRoutine                 = "rename_routine"
)

// Legacy insight-driven types (kept for compatibility).
const (
	TypeReduceVolume     = "reduce_volume"
	TypeAddRestDay       = "add_rest_day"
	TypeIncreaseRecovery = "increase_recovery"
	TypeImproveNutrition = "improve_nutrition"
	TypeProgressionStall = "progression_stall"
)

type Action struct {
	ID         string          `json:"id"`
	UserID     string          `json:"user_id"`
	InsightID  *string         `json:"insight_id,omitempty"`
	SourceType *string         `json:"source_type,omitempty"`
	SourceID   *string         `json:"source_id,omitempty"`
	ActionType string          `json:"action_type"`
	TargetType *string         `json:"target_type,omitempty"`
	TargetID   *string         `json:"target_id,omitempty"`
	Payload    json.RawMessage `json:"payload,omitempty"`
	Reason     *string         `json:"reason,omitempty"`
	Status     string          `json:"status"`
	CreatedAt  time.Time       `json:"created_at"`
	ResolvedAt *time.Time      `json:"resolved_at,omitempty"`
	AppliedAt  *time.Time      `json:"applied_at,omitempty"`
}

func (a *Action) IsResolved() bool {
	return a.Status != StatusPending
}

type ExerciseMatch struct {
	ExerciseID   string `json:"exercise_id"`
	ExerciseName string `json:"exercise_name"`
}

type Clarification struct {
	Required        bool            `json:"clarification_required"`
	Message         string          `json:"message"`
	PossibleMatches []ExerciseMatch `json:"possible_matches,omitempty"`
}
