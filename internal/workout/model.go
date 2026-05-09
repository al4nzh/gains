package workout

import "time"

type Workout struct {
	ID          string     `json:"id"           db:"id"`
	UserID      string     `json:"user_id"      db:"user_id"`
	RoutineID   *string    `json:"routine_id,omitempty"   db:"routine_id"`
	Name        *string    `json:"name,omitempty"         db:"name"`
	StartedAt   time.Time  `json:"started_at"   db:"started_at"`
	CompletedAt *time.Time `json:"completed_at,omitempty" db:"completed_at"`
	Notes       *string    `json:"notes,omitempty"        db:"notes"`
	CreatedAt   time.Time  `json:"created_at"   db:"created_at"`

	Sets []Set `json:"sets,omitempty" db:"-"`
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

func (w *Workout) IsComplete() bool {
	return w.CompletedAt != nil
}

func (w *Workout) Duration() time.Duration {
	if w.CompletedAt == nil {
		return 0
	}
	return w.CompletedAt.Sub(w.StartedAt)
}

// Volume is total reps * weight across all sets. Useful for the action engine.
func (w *Workout) Volume() float64 {
	var total float64
	for _, s := range w.Sets {
		if s.Reps == nil || s.WeightKg == nil {
			continue
		}
		total += float64(*s.Reps) * *s.WeightKg
	}
	return total
}
