package adaptiverecommendations

import "errors"

var (
	ErrNotFound            = errors.New("not found")
	ErrRoutineNotYours     = errors.New("routine not found")
	ErrWorkoutNotYours     = errors.New("workout not found")
	ErrWorkoutNotActive    = errors.New("workout is not active")
	ErrRecommendationUnknown = errors.New("unknown recommendation")
	ErrAlreadyApplied      = errors.New("recommendation already applied")
)
