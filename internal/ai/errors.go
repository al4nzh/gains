package ai

import "errors"

var (
	ErrNotFound             = errors.New("not found")
	ErrConversationNotFound = errors.New("conversation not found")
	ErrWorkoutNotCompleted  = errors.New("workout is not completed")
	ErrOpenAINotConfigured  = errors.New("OPENAI_API_KEY is not configured")
	ErrChatMessageRequired  = errors.New("message is required")
)
