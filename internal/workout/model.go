package workout

import (
	"encoding/json"
	"time"
)

type Workout struct {
	ID               string           `json:"id"            db:"id"`
	UserID           string           `json:"user_id"       db:"user_id"`
	RoutineID        *string          `json:"routine_id,omitempty"   db:"routine_id"`
	Name             *string          `json:"name,omitempty"         db:"name"`
	StartedAt        time.Time        `json:"started_at"    db:"started_at"`
	CompletedAt      *time.Time       `json:"completed_at,omitempty" db:"completed_at"`
	Notes            *string          `json:"notes,omitempty"        db:"notes"`
	CreatedAt        time.Time        `json:"created_at"    db:"created_at"`
	TotalVolumeKg    *float64         `json:"total_volume_kg,omitempty" db:"total_volume_kg"`
	DurationSeconds  *int             `json:"duration_seconds,omitempty" db:"duration_seconds"`
	Stats            json.RawMessage  `json:"stats,omitempty" db:"stats"`

	Sets []SetOut `json:"sets,omitempty" db:"-"`
}

type Set struct {
	ID         string    `json:"id"          db:"id"`
	WorkoutID  string    `json:"workout_id"  db:"workout_id"`
	ExerciseID string    `json:"exercise_id" db:"exercise_id"`
	SetNumber  int       `json:"set_number"  db:"set_number"`
	Reps       *int      `json:"reps,omitempty"      db:"reps"`
	WeightKg   *float64  `json:"weight_kg,omitempty" db:"weight_kg"`
	RPE        *float64  `json:"rpe,omitempty"       db:"rpe"`
	IsFailure  bool      `json:"is_failure"  db:"is_failure"`
	Notes      *string   `json:"notes,omitempty" db:"notes"`
	CreatedAt  time.Time `json:"created_at"  db:"created_at"`
}

type SetOut struct {
	Set
	ExerciseName string `json:"exercise_name"`
}

// FinishStats is stored in workouts.stats and returned from POST .../finish.
type FinishStats struct {
	TotalVolumeKg   float64            `json:"total_volume_kg"`
	DurationSeconds int                `json:"duration_seconds"`
	SetCount        int                `json:"set_count"`
	ExerciseCount   int                `json:"exercise_count"`
	E1RMByExercise  []E1RMExerciseStat `json:"e1rm_by_exercise"`
	PRs             []PRStat           `json:"prs"`
	StrengthElo     *FinishEloStat     `json:"strength_elo,omitempty"`
}

type E1RMExerciseStat struct {
	ExerciseID   string  `json:"exercise_id"`
	ExerciseName string  `json:"exercise_name"`
	BestE1RMKg   float64 `json:"best_e1rm_kg"`
}

type PRStat struct {
	ExerciseID          string  `json:"exercise_id"`
	ExerciseName        string  `json:"exercise_name"`
	PreviousBestE1RMKg  float64 `json:"previous_best_e1rm_kg"`
	NewBestE1RMKg       float64 `json:"new_best_e1rm_kg"`
}

type FinishEloStat struct {
	BeforeElo      int     `json:"before"`
	AfterElo       int     `json:"after"`
	Delta          int     `json:"delta"`
	Change30d      int     `json:"change_30d"`
	BodyweightKg   float64 `json:"bodyweight_kg"`
	SessionScoreBW float64 `json:"session_score_bw"`
	Skipped        bool    `json:"skipped,omitempty"` // true if no bodyweight → no Elo change
}

func (w *Workout) IsComplete() bool {
	return w.CompletedAt != nil
}

func (w *Workout) VolumeFromSets(sets []Set) float64 {
	var total float64
	for _, s := range sets {
		if s.Reps == nil || s.WeightKg == nil {
			continue
		}
		total += float64(*s.Reps) * *s.WeightKg
	}
	return total
}
