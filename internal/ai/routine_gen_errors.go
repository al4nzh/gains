package ai

import "errors"

var (
	ErrRoutineDraftNotFound   = errors.New("routine draft not found")
	ErrRoutineDraftNotPending = errors.New("routine draft is not pending confirmation")
	ErrRoutineGenMessageRequired = errors.New("message is required")
)
