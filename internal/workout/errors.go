package workout

import "errors"

var (
	ErrNotFound          = errors.New("workout not found")
	ErrAlreadyFinished   = errors.New("workout already finished")
	ErrSetNotFound       = errors.New("set not found")
	ErrExerciseNotFound  = errors.New("exercise not found")
	ErrRoutineNotYours   = errors.New("routine not found")
	ErrInvalidSetPayload = errors.New("invalid set: need positive reps and weight for logged work")
)
