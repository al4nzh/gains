package adaptiverecommendations

import "encoding/json"

// RecommendationType is a machine-readable adjustment category.
type RecommendationType string

const (
	TypeReduceVolume     RecommendationType = "reduce_volume"
	TypeSwapExercise       RecommendationType = "swap_exercise"
	TypeReduceIntensity    RecommendationType = "reduce_intensity"
	TypeIncreaseWeight     RecommendationType = "increase_weight"
	TypeDeload             RecommendationType = "deload"
	TypeReduceMuscleVolume RecommendationType = "reduce_muscle_volume"
)

// SuggestedChange describes what to change when the user taps Apply.
type SuggestedChange struct {
	SetsDelta             *int     `json:"sets_delta,omitempty"`
	WeightDeltaKg         *float64 `json:"weight_delta_kg,omitempty"`
	WeightDeltaPct        *float64 `json:"weight_delta_pct,omitempty"`
	ReplaceExerciseID     *string  `json:"replace_exercise_id,omitempty"`
	ReplaceExerciseName   *string  `json:"replace_exercise_name,omitempty"`
}

// Recommendation is one actionable card for the Train / workout UI.
type Recommendation struct {
	ID                      string             `json:"id"`
	Type                    RecommendationType `json:"type"`
	Scope                   string             `json:"scope"` // routine | exercise
	TargetExerciseID        *string            `json:"target_exercise_id,omitempty"`
	TargetRoutineExerciseID *string            `json:"target_routine_exercise_id,omitempty"`
	TargetMuscleGroup       *string            `json:"target_muscle_group,omitempty"`
	Reason                  string             `json:"reason"`
	Message                 string             `json:"message"`
	SuggestedChange         SuggestedChange    `json:"suggested_change"`
	Confidence              string             `json:"confidence"` // low | medium | high
}

// ListResponse is returned by GET recommendation endpoints.
type ListResponse struct {
	Recommendations []Recommendation `json:"recommendations"`
	ContextSummary  *ContextSummary  `json:"context_summary,omitempty"`
}

// ContextSummary gives the client a short snapshot of signals used (optional UI).
type ContextSummary struct {
	SharpnessScore    *int     `json:"sharpness_score,omitempty"`
	LatestSleepHours  *float64 `json:"latest_sleep_hours,omitempty"`
	LatestEnergy      *int     `json:"latest_energy,omitempty"`
	HasInjuryNotes    bool     `json:"has_injury_notes"`
	RecoveryCheckinOK bool     `json:"recovery_checkin_ok"`
}

// AppliedAdjustment is stored on the active workout (session-only; routine unchanged).
type AppliedAdjustment struct {
	RecommendationID        string             `json:"recommendation_id"`
	Type                    RecommendationType `json:"type"`
	TargetExerciseID        *string            `json:"target_exercise_id,omitempty"`
	TargetRoutineExerciseID *string            `json:"target_routine_exercise_id,omitempty"`
	TargetMuscleGroup       *string            `json:"target_muscle_group,omitempty"`
	Change                  SuggestedChange    `json:"change"`
	AppliedAt               string             `json:"applied_at"`
}

// ApplyResponse is returned after POST apply.
type ApplyResponse struct {
	WorkoutID            string              `json:"workout_id"`
	Applied              AppliedAdjustment   `json:"applied"`
	AdaptiveAdjustments  []AppliedAdjustment `json:"adaptive_adjustments"`
}

// evalInput is internal rule-engine input.
type evalInput struct {
	RoutineID            string
	SharpnessScore       int
	HasSharpness         bool
	LatestSleepHours     float64
	HasSleep             bool
	LatestEnergy         int
	HasEnergy            bool
	InjuryText           string
	RoutineExercises     []routineExerciseEval
	ExerciseTrends       map[string]string // exercise_id -> up|down|flat|no_data
	ExerciseSessionCount map[string]int
	WeeklyVolByMuscle    map[string]float64
	PriorVolByMuscle     map[string]float64
	ExerciseMeta         map[string]exerciseMeta
	LastBestLoad         map[string]lastSetLoadEval // exercise_id -> last routine session best set
}

type lastSetLoadEval struct {
	Reps     int
	WeightKg float64
}

type routineExerciseEval struct {
	RoutineExerciseID string
	ExerciseID        string
	ExerciseName      string
	MuscleGroup       string
	TargetSets        *int
	TargetWeightKg    *float64
	Position          int
	IsAccessory       bool
}

type exerciseMeta struct {
	ID          string
	Name        string
	MuscleGroup string
}

// ParseAdjustments unmarshals workout.adaptive_adjustments JSON.
func ParseAdjustments(raw json.RawMessage) ([]AppliedAdjustment, error) {
	if len(raw) == 0 || string(raw) == "null" {
		return []AppliedAdjustment{}, nil
	}
	var out []AppliedAdjustment
	if err := json.Unmarshal(raw, &out); err != nil {
		return nil, err
	}
	if out == nil {
		return []AppliedAdjustment{}, nil
	}
	return out, nil
}
