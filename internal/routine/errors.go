package routine

import "errors"

var (
	ErrNotFound         = errors.New("routine not found")
	ErrTemplateNotFound = errors.New("routine template not found")
	ErrExerciseNotFound = errors.New("exercise not found")
	ErrRoutineExerciseNotFound = errors.New("routine exercise not found")
	ErrInvalidPosition  = errors.New("invalid position")
)
