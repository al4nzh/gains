package ai

import "errors"

var (
	ErrActionNotFound      = errors.New("action not found")
	ErrActionNotPending    = errors.New("action is not pending")
	ErrUnsupportedAction   = errors.New("unsupported action type")
	ErrActionValidation    = errors.New("action validation failed")
	ErrExerciseAmbiguous   = errors.New("exercise name is ambiguous")
	ErrExerciseNotResolved = errors.New("exercise not found")
)
