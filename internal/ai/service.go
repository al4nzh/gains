package ai

import (
	"context"
	"encoding/json"
	"errors"
	"strings"

	"gainsai/internal/config"
	"gainsai/internal/workout"
)

type Service struct {
	repo      *Repository
	workouts  *workout.Repository
	cfg       *config.Config
	analytics WorkoutContextJSONProvider
}

func NewService(repo *Repository, workouts *workout.Repository, cfg *config.Config, analytics WorkoutContextJSONProvider) *Service {
	return &Service{repo: repo, workouts: workouts, cfg: cfg, analytics: analytics}
}

// AnalyzeWorkout generates or returns the saved post-workout analysis (at most one per workout_id).
func (s *Service) AnalyzeWorkout(ctx context.Context, userID, workoutID string) (*AnalyzeWorkoutResponse, error) {
	w, err := s.workouts.GetWorkoutForUser(ctx, userID, workoutID)
	if err != nil {
		if errors.Is(err, workout.ErrNotFound) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	if w.CompletedAt == nil {
		return nil, ErrWorkoutNotCompleted
	}

	existing, err := s.repo.GetInsightByWorkoutID(ctx, userID, workoutID)
	if err != nil {
		return nil, err
	}
	if existing != nil {
		return analyzeResponseFromInsight(existing, workoutID), nil
	}

	if strings.TrimSpace(s.cfg.OpenAIAPIKey) == "" {
		return nil, ErrOpenAINotConfigured
	}

	payload, err := s.analytics.WorkoutContextJSON(ctx, userID, workoutID)
	if err != nil {
		return nil, err
	}

	model := s.cfg.OpenAIModel
	if model == "" {
		model = "gpt-4o-mini"
	}

	raw, err := ChatCompletion(ctx, s.cfg.OpenAIAPIKey, model, analyzeWorkoutSystemPrompt, string(payload))
	if err != nil {
		return nil, err
	}
	title, message := parseTitleMessage(raw)

	metrics, err := json.Marshal(map[string]any{
		"source":     "analyze-workout",
		"workout_id": workoutID,
	})
	if err != nil {
		return nil, err
	}

	ins, err := s.repo.InsertWorkoutInsight(ctx, userID, workoutID, InsightTypeWorkoutAnalysis, title, message, metrics, &model)
	if errors.Is(err, ErrDuplicateWorkoutInsight) {
		again, err := s.repo.GetInsightByWorkoutID(ctx, userID, workoutID)
		if err != nil {
			return nil, err
		}
		if again == nil {
			return nil, errors.New("ai: duplicate insert but insight not found")
		}
		return analyzeResponseFromInsight(again, workoutID), nil
	}
	if err != nil {
		return nil, err
	}
	return analyzeResponseFromInsight(ins, workoutID), nil
}

// ListInsights returns stored insights only (never calls OpenAI).
func (s *Service) ListInsights(ctx context.Context, userID string, limit int) ([]InsightListItem, error) {
	list, err := s.repo.ListInsightsForUser(ctx, userID, limit)
	if err != nil {
		return nil, err
	}
	out := make([]InsightListItem, 0, len(list))
	for _, ins := range list {
		out = append(out, InsightListItem{
			ID:          ins.ID,
			WorkoutID:   ins.WorkoutID,
			InsightType: ins.InsightType,
			Title:       ins.Title,
			Summary:     ins.GeneratedText,
			CreatedAt:   ins.CreatedAt,
		})
	}
	return out, nil
}

func analyzeResponseFromInsight(ins *Insight, workoutID string) *AnalyzeWorkoutResponse {
	wid := workoutID
	if ins.WorkoutID != nil && *ins.WorkoutID != "" {
		wid = *ins.WorkoutID
	}
	var structured json.RawMessage
	if len(ins.Metrics) > 0 && string(ins.Metrics) != "{}" && string(ins.Metrics) != "null" {
		structured = ins.Metrics
	}
	return &AnalyzeWorkoutResponse{
		ID:             ins.ID,
		WorkoutID:      wid,
		InsightType:    ins.InsightType,
		Title:          ins.Title,
		Message:        ins.GeneratedText,
		StructuredJSON: structured,
		CreatedAt:      ins.CreatedAt,
	}
}

type llmTitleMessage struct {
	Title   string `json:"title"`
	Message string `json:"message"`
}

func parseTitleMessage(raw string) (title, message string) {
	raw = stripJSONFences(strings.TrimSpace(raw))
	var p llmTitleMessage
	if err := json.Unmarshal([]byte(raw), &p); err == nil && strings.TrimSpace(p.Message) != "" {
		t := strings.TrimSpace(p.Title)
		if t == "" {
			t = "Workout analysis"
		}
		return t, strings.TrimSpace(p.Message)
	}
	if raw == "" {
		return "Workout analysis", "(No analysis text returned.)"
	}
	return "Workout analysis", raw
}

func stripJSONFences(s string) string {
	s = strings.TrimSpace(s)
	if !strings.HasPrefix(s, "```") {
		return s
	}
	end := strings.LastIndex(s, "```")
	var inner string
	if end <= 3 {
		inner = strings.TrimSpace(strings.TrimPrefix(s, "```"))
	} else {
		inner = strings.TrimSpace(s[3:end])
	}
	if idx := strings.IndexByte(inner, '\n'); idx >= 0 {
		first := strings.TrimSpace(inner[:idx])
		if strings.EqualFold(first, "json") {
			inner = strings.TrimSpace(inner[idx+1:])
		}
	}
	return strings.TrimSpace(inner)
}
