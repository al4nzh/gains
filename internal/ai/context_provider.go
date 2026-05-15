package ai

import "context"

// WorkoutContextJSONProvider is implemented by analytics.Service. It must return the same JSON
// body as GET /analytics/workouts/:workoutId/context (see analytics.Service.WorkoutContextJSON).
type WorkoutContextJSONProvider interface {
	WorkoutContextJSON(ctx context.Context, userID, workoutID string) ([]byte, error)
}
