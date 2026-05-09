package routine

import "time"

type Routine struct {
	ID          string    `json:"id"           db:"id"`
	UserID      string    `json:"user_id"      db:"user_id"`
	Name        string    `json:"name"         db:"name"`
	Description *string   `json:"description,omitempty" db:"description"`
	CreatedAt   time.Time `json:"created_at"   db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"   db:"updated_at"`

	Exercises []RoutineExercise `json:"exercises,omitempty" db:"-"`
}

type RoutineExercise struct {
	ID             string   `json:"id"          db:"id"`
	RoutineID      string   `json:"routine_id"  db:"routine_id"`
	ExerciseID     string   `json:"exercise_id" db:"exercise_id"`
	Position       int      `json:"position"    db:"position"`
	TargetSets     *int     `json:"target_sets,omitempty"      db:"target_sets"`
	TargetReps     *int     `json:"target_reps,omitempty"      db:"target_reps"`
	TargetWeightKg *float64 `json:"target_weight_kg,omitempty" db:"target_weight_kg"`
	Notes          *string  `json:"notes,omitempty"            db:"notes"`
}
