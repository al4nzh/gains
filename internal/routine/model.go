package routine

import "time"

type Routine struct {
	ID          string    `json:"id"           db:"id"`
	UserID      string    `json:"user_id"      db:"user_id"`
	Name        string    `json:"name"         db:"name"`
	Description *string   `json:"description,omitempty" db:"description"`
	CreatedAt   time.Time `json:"created_at"   db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"   db:"updated_at"`

	ExerciseCount int `json:"exercise_count,omitempty" db:"-"`
	Exercises     []RoutineExerciseOut `json:"exercises,omitempty"      db:"-"`
}

type RoutineExercise struct {
	ID             string   `json:"id"           db:"id"`
	RoutineID      string   `json:"routine_id"   db:"routine_id"`
	ExerciseID     string   `json:"exercise_id"  db:"exercise_id"`
	Position       int      `json:"position"     db:"position"`
	TargetSets     *int     `json:"target_sets,omitempty"       db:"target_sets"`
	TargetRepMin   *int     `json:"target_rep_min,omitempty"    db:"target_rep_min"`
	TargetRepMax   *int     `json:"target_rep_max,omitempty"      db:"target_rep_max"`
	TargetRPE      *float64 `json:"target_rpe,omitempty"        db:"target_rpe"`
	RestSeconds    *int     `json:"rest_seconds,omitempty"      db:"rest_seconds"`
	Notes          *string  `json:"notes,omitempty"             db:"notes"`
	TargetWeightKg *float64 `json:"target_weight_kg,omitempty"  db:"target_weight_kg"`
}

// RoutineExerciseOut is returned to clients (includes exercise name).
type RoutineExerciseOut struct {
	RoutineExercise
	ExerciseName string `json:"exercise_name"`
}

type RoutineTemplate struct {
	ID             string    `json:"id"           db:"id"`
	Name           string    `json:"name"         db:"name"`
	Description    *string   `json:"description,omitempty" db:"description"`
	CreatedAt      time.Time `json:"created_at"   db:"created_at"`
	ExerciseCount  int       `json:"exercise_count,omitempty" db:"-"`

	Exercises []RoutineTemplateExerciseOut `json:"exercises,omitempty" db:"-"`
}

type RoutineTemplateExercise struct {
	ID           string   `json:"id"          db:"id"`
	TemplateID   string   `json:"template_id" db:"template_id"`
	ExerciseID   string   `json:"exercise_id" db:"exercise_id"`
	Position     int      `json:"position"    db:"position"`
	TargetSets   *int     `json:"target_sets,omitempty"    db:"target_sets"`
	TargetRepMin *int     `json:"target_rep_min,omitempty" db:"target_rep_min"`
	TargetRepMax *int     `json:"target_rep_max,omitempty" db:"target_rep_max"`
	TargetRPE    *float64 `json:"target_rpe,omitempty"     db:"target_rpe"`
	RestSeconds  *int     `json:"rest_seconds,omitempty"   db:"rest_seconds"`
	Notes        *string  `json:"notes,omitempty"          db:"notes"`
}

type RoutineTemplateExerciseOut struct {
	RoutineTemplateExercise
	ExerciseName string `json:"exercise_name"`
}
