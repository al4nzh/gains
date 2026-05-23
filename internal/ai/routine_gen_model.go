package ai

import (
	"time"

	"gainsai/internal/actionengine"
	"gainsai/internal/routine"
)

const (
	RoutineDraftStatusDraft     = "draft"
	RoutineDraftStatusConfirmed = "confirmed"
	RoutineDraftStatusRejected  = "rejected"
	RoutineDraftStatusExpired   = "expired"
)

const (
	maxRoutinesPerDraft   = 7
	maxExercisesPerRoutine = 7
	maxCatalogForLLM      = 500
)

// GenerateRoutinesRequest is POST /ai/generate-routines.
type GenerateRoutinesRequest struct {
	Message string `json:"message"`
}

// DraftExercise is one line in a generated routine preview.
type DraftExercise struct {
	ExerciseID   string  `json:"exercise_id"`
	ExerciseName string  `json:"exercise_name"`
	TargetSets   *int    `json:"target_sets,omitempty"`
	TargetRepMin *int    `json:"target_rep_min,omitempty"`
	TargetRepMax *int    `json:"target_rep_max,omitempty"`
	RestSeconds  *int    `json:"rest_seconds,omitempty"`
	Notes        *string `json:"notes,omitempty"`
}

// DraftRoutine is one routine in a draft plan.
type DraftRoutine struct {
	Name        string          `json:"name"`
	Description *string         `json:"description,omitempty"`
	Exercises   []DraftExercise `json:"exercises"`
}

// GenerateRoutinesResponse is POST /ai/generate-routines 200 body.
type GenerateRoutinesResponse struct {
	DraftID         string                      `json:"draft_id,omitempty"`
	Title           string                      `json:"title,omitempty"`
	Routines        []DraftRoutine              `json:"routines,omitempty"`
	Clarification   *actionengine.Clarification `json:"clarification,omitempty"`
}

// ConfirmRoutineDraftResponse is POST /ai/generated-routines/:draftId/confirm 200 body.
type ConfirmRoutineDraftResponse struct {
	DraftID  string            `json:"draft_id"`
	Routines []routine.Routine `json:"routines"`
}

// storedRoutineDraft is persisted in ai_routine_drafts.draft_json after validation.
type storedRoutineDraft struct {
	Title    string         `json:"title"`
	Routines []DraftRoutine `json:"routines"`
}

type routineDraftRow struct {
	ID             string    `json:"id"`
	UserID         string    `json:"user_id"`
	RequestMessage string    `json:"request_message"`
	Title          string    `json:"title"`
	Status         string    `json:"status"`
	CreatedAt      time.Time `json:"created_at"`
	ConfirmedAt    *time.Time `json:"confirmed_at,omitempty"`
	Payload        storedRoutineDraft
}

// llmRoutineGenOutput is parsed from OpenAI (untrusted).
type llmRoutineGenOutput struct {
	Title    string           `json:"title"`
	Routines []llmDraftRoutine `json:"routines"`
}

type llmDraftRoutine struct {
	Name        string            `json:"name"`
	Description *string           `json:"description"`
	Exercises   []llmDraftExercise `json:"exercises"`
}

type llmDraftExercise struct {
	ExerciseName string  `json:"exercise_name"`
	TargetSets   *int    `json:"target_sets"`
	TargetRepMin *int    `json:"target_rep_min"`
	TargetRepMax *int    `json:"target_rep_max"`
	RestSeconds  *int    `json:"rest_seconds"`
	Notes        *string `json:"notes"`
}

// exerciseLibraryEntry is sent to the model (compact catalog row).
type exerciseLibraryEntry struct {
	ExerciseID     string  `json:"exercise_id"`
	ExerciseName   string  `json:"exercise_name"`
	PrimaryMuscle  *string `json:"primary_muscle,omitempty"`
	Equipment      *string `json:"equipment,omitempty"`
}
