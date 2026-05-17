package ai

import "context"

// AnalyticsContextProvider is implemented by analytics.Service.
type AnalyticsContextProvider interface {
	WorkoutContextJSON(ctx context.Context, userID, workoutID string) ([]byte, error)
	CoachContextJSON(ctx context.Context, userID string) ([]byte, error)
}
