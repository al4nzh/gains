package workout

import "errors"

var (
	ErrNotFound            = errors.New("workout not found")
	ErrAlreadyFinished     = errors.New("workout already finished")
	ErrActiveWorkoutExists = errors.New("active workout already in progress")
	ErrSetNotFound         = errors.New("set not found")
	ErrExerciseNotFound    = errors.New("exercise not found")
	ErrRoutineNotYours     = errors.New("routine not found")
	ErrInvalidSetPayload   = errors.New("invalid set: need positive reps and weight for logged work")
)

// ActiveWorkoutConflict is returned when POST /workouts is called while a session is in progress.
type ActiveWorkoutConflict struct {
	WorkoutID string
}

func (e *ActiveWorkoutConflict) Error() string {
	return ErrActiveWorkoutExists.Error()
}
