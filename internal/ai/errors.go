package ai

import "errors"

var (
	ErrNotFound            = errors.New("not found")
	ErrWorkoutNotCompleted = errors.New("workout is not completed")
	ErrOpenAINotConfigured = errors.New("OPENAI_API_KEY is not configured")
)
