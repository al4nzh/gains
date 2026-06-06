package analytics

import (
	"encoding/json"
	"time"

	"gainsai/internal/actionengine"
	"gainsai/internal/ai"
	"gainsai/internal/profile"
	"gainsai/internal/workout"
)

// HomeResponse is the lightweight home tab payload (GET /home).
type HomeResponse struct {
	StrengthElo            *int               `json:"strength_elo,omitempty"`
	StrengthEloRank        *string            `json:"strength_elo_rank,omitempty"`
	StrengthEloPercentile  *int               `json:"strength_elo_percentile,omitempty"`
	EloChange30d           *int               `json:"elo_change_30d,omitempty"`
	Sharpness              *SharpnessOverview `json:"sharpness"`
	LatestWorkout          *WorkoutSnapshot   `json:"latest_workout,omitempty"`
	WeeklyVolumeKg         float64            `json:"weekly_volume_kg"`
	WeeklyVolumeWindowDays int                `json:"weekly_volume_window_days"`
	WorkoutConsistency     WorkoutConsistency `json:"workout_consistency"`
	StreakDays             int                `json:"streak_days"`
	TrainToday             *TrainTodayRecommendation `json:"train_today,omitempty"`
}

// SetLoadSummary is reps + weight for one top set.
type SetLoadSummary struct {
	Reps     *int     `json:"reps,omitempty"`
	WeightKg *float64 `json:"weight_kg,omitempty"`
}

// ExerciseListItem is one row for GET /analytics/exercises (progress list).
type ExerciseListItem struct {
	ExerciseID         string          `json:"exercise_id"`
	ExerciseName       string          `json:"exercise_name"`
	LatestBestSet      *SetLoadSummary `json:"latest_best_set,omitempty"`
	LatestE1RMKg       float64         `json:"latest_e1rm_kg"`
	AbsoluteBestE1RMKg float64         `json:"absolute_best_e1rm_kg"`
	AbsoluteBestSet    *SetLoadSummary `json:"absolute_best_set,omitempty"`
	E1RMChangeKg       float64         `json:"e1rm_change_kg"`
	E1RMChangePct      *float64        `json:"e1rm_change_pct,omitempty"`
	DataPoints         int             `json:"data_points"`
	Trend              string          `json:"trend"` // up | flat | down
}

// ExercisesListResponse is GET /analytics/exercises.
type ExercisesListResponse struct {
	Exercises []ExerciseListItem `json:"exercises"`
}

// ExerciseDetailSetEntry is the best set for one exercise inside one workout.
type ExerciseDetailSetEntry struct {
	Reps     *int     `json:"reps,omitempty"`
	WeightKg *float64 `json:"weight_kg,omitempty"`
}

// ExerciseDetailWorkoutEntry is one completed session in GET /analytics/exercises/:id.
type ExerciseDetailWorkoutEntry struct {
	WorkoutID   string                 `json:"workout_id"`
	CompletedAt string                 `json:"completed_at"`
	BestSet     ExerciseDetailSetEntry `json:"best_set"`
	BestE1RMKg  float64                `json:"best_e1rm_kg"`
	VolumeKg    float64                `json:"volume_kg"`
	PRs         []workout.PRStat       `json:"prs,omitempty"`
}

// ExerciseDetailLatestComparison compares the newest history session vs the one before it (same exercise).
type ExerciseDetailLatestComparison struct {
	PreviousCompletedAt string          `json:"previous_completed_at"`
	E1RMChangeKg        float64         `json:"e1rm_change_kg"`
	E1RMChangePct       *float64        `json:"e1rm_change_pct,omitempty"`
	VolumeChangeKg      float64         `json:"volume_change_kg"`
	VolumeChangePct     *float64        `json:"volume_change_pct,omitempty"`
	BestSetPrevious     *SetLoadSummary `json:"best_set_previous,omitempty"`
	BestSetCurrent      *SetLoadSummary `json:"best_set_current,omitempty"`
}

// ExerciseDetailResponse is GET /analytics/exercises/:exerciseId.
type ExerciseDetailResponse struct {
	ExerciseID              string                          `json:"exercise_id"`
	ExerciseName            string                          `json:"exercise_name"`
	AbsoluteBestE1RMKg      float64                         `json:"absolute_best_e1rm_kg"`
	AbsoluteBestSet         *ExerciseDetailSetEntry         `json:"absolute_best_set,omitempty"`
	AbsoluteBestWorkoutID   string                          `json:"absolute_best_workout_id,omitempty"`
	AbsoluteBestCompletedAt string                          `json:"absolute_best_completed_at,omitempty"`
	History                 []ExerciseDetailWorkoutEntry    `json:"history"`
	LatestComparison        *ExerciseDetailLatestComparison `json:"latest_comparison,omitempty"`
	TrendSummary            string                          `json:"trend_summary"`
}

// WorkoutContextExerciseCompare compares one exercise vs the previous same-routine session.
type WorkoutContextExerciseCompare struct {
	ExerciseID       string   `json:"exercise_id"`
	ExerciseName     string   `json:"exercise_name"`
	CurrentE1RMKg    float64  `json:"current_e1rm_kg"`
	PreviousE1RMKg   *float64 `json:"previous_e1rm_kg,omitempty"`
	E1RMDeltaKg      *float64 `json:"e1rm_delta_kg,omitempty"`
	CurrentVolumeKg  float64  `json:"current_volume_kg"`
	PreviousVolumeKg *float64 `json:"previous_volume_kg,omitempty"`
}

// WorkoutContextProfileBasics is a small slice of profile for workout / AI context.
type WorkoutContextProfileBasics struct {
	Goal        *string  `json:"goal,omitempty"`
	Experience  *string  `json:"experience,omitempty"`
	Gender      *string  `json:"gender,omitempty"`
	InjuryNotes *string  `json:"injury_notes,omitempty"`
	StrengthElo *int     `json:"strength_elo,omitempty"`
	WeightKg    *float64 `json:"weight_kg,omitempty"`
}

// WorkoutContextRecentExercise is a per-lift summary on a recent workout (for AI comparison).
type WorkoutContextRecentExercise struct {
	ExerciseID   string          `json:"exercise_id,omitempty"`
	ExerciseName string          `json:"exercise_name"`
	BestSet      *SetLoadSummary `json:"best_set,omitempty"`
	BestE1RMKg   float64         `json:"best_e1rm_kg"`
}

// WorkoutContextRecentWorkout is a completed session plus exercise summaries for context.
type WorkoutContextRecentWorkout struct {
	WorkoutID       string                         `json:"workout_id"`
	CompletedAt     string                         `json:"completed_at"`
	TotalVolumeKg   float64                        `json:"total_volume_kg"`
	DurationSeconds int                            `json:"duration_seconds"`
	SetCount        int                            `json:"set_count"`
	Exercises       []WorkoutContextRecentExercise `json:"exercises,omitempty"`
}

// WorkoutContextResponse is GET /analytics/workouts/:workoutId/context.
type WorkoutContextResponse struct {
	Workout                *workout.Workout                `json:"workout"`
	ProfileBasics          *WorkoutContextProfileBasics    `json:"profile_basics"`
	PreviousSameRoutine    *LastWorkoutComparison          `json:"previous_same_routine,omitempty"`
	ExerciseComparisons    []WorkoutContextExerciseCompare `json:"exercise_comparisons,omitempty"`
	PRs                    []workout.PRStat                `json:"prs,omitempty"`
	StrengthEloDelta       *int                            `json:"strength_elo_delta,omitempty"`
	RecentRecoveryCheckins []RecoveryCheckinLite           `json:"recent_recovery_checkins,omitempty"`
	Sharpness              *SharpnessOverview              `json:"sharpness,omitempty"`
	RelevantRecentWorkouts []WorkoutContextRecentWorkout   `json:"relevant_recent_workouts,omitempty"`
}

func workoutContextProfileBasicsFrom(p *profile.Profile) *WorkoutContextProfileBasics {
	if p == nil {
		return &WorkoutContextProfileBasics{}
	}
	return &WorkoutContextProfileBasics{
		Goal:        p.FitnessGoal,
		Experience:  p.TrainingExperience,
		Gender:      p.Gender,
		InjuryNotes: p.InjuryNotes,
		StrengthElo: p.StrengthElo,
		WeightKg:    p.WeightKg,
	}
}

// RecoveryCheckinLite is a slim check-in row for AI / workout context payloads.
type RecoveryCheckinLite struct {
	CheckinDate     string  `json:"checkin_date"`
	SleepHours      float64 `json:"sleep_hours"`
	EnergyReadiness int     `json:"energy_readiness"`
	CaloriesKcal    int     `json:"calories_kcal"`
	ProteinG        int     `json:"protein_g"`
}

// CoachProfileView mirrors GET /profile field names for AI consumers.
type CoachProfileView struct {
	UserID                string     `json:"user_id"`
	Age                   *int       `json:"age,omitempty"`
	HeightCm              *float64   `json:"height_cm,omitempty"`
	WeightKg              *float64   `json:"weight_kg,omitempty"`
	Gender                *string    `json:"gender,omitempty"`
	Goal                  *string    `json:"goal,omitempty"`
	Experience            *string    `json:"experience,omitempty"`
	PreferredSplit        *string    `json:"preferred_split,omitempty"`
	InjuryNotes           *string    `json:"injury_notes,omitempty"`
	ActivityLevel         *string    `json:"activity_level,omitempty"`
	StrengthElo           *int       `json:"strength_elo,omitempty"`
	StrengthEloRank       *string    `json:"strength_elo_rank,omitempty"`
	StrengthEloChange30d  *int       `json:"strength_elo_change_30d,omitempty"`
	LastStrengthEloUpdate *time.Time `json:"last_strength_elo_update,omitempty"`
	UpdatedAt             *time.Time `json:"updated_at,omitempty"`
}

// CoachStrengthEloSummary is a compact Strength Elo block for coach / AI (GET /analytics/coach-context).
type CoachStrengthEloSummary struct {
	CurrentElo  *int       `json:"current_elo,omitempty"`
	Rank        *string    `json:"rank,omitempty"`
	Change30d   *int       `json:"change_30d,omitempty"`
	LastUpdated *time.Time `json:"last_updated,omitempty"`
}

// CoachLatestRecoveryCheckin is the most recent check-in in the 7d window (by checkin_date).
type CoachLatestRecoveryCheckin struct {
	CheckinDate     string  `json:"checkin_date"`
	SleepHours      float64 `json:"sleep_hours"`
	EnergyReadiness int     `json:"energy_readiness"`
	CaloriesKcal    int     `json:"calories_kcal"`
	ProteinG        int     `json:"protein_g"`
	Notes           *string `json:"notes,omitempty"`
}

// CoachRecovery7dAverages are simple means over check-ins in the same window as sharpness (last 7d UTC).
type CoachRecovery7dAverages struct {
	DaysWithData    int     `json:"days_with_data"`
	SleepHours      float64 `json:"sleep_hours"`
	EnergyReadiness float64 `json:"energy_readiness"`
	CaloriesKcal    float64 `json:"calories_kcal"`
	ProteinG        float64 `json:"protein_g"`
}

// CoachRecoveryContext pairs the latest check-in with 7d averages for coach chat.
type CoachRecoveryContext struct {
	Latest     *CoachLatestRecoveryCheckin `json:"latest,omitempty"`
	Averages7d CoachRecovery7dAverages     `json:"averages_7d"`
}

// CoachWorkoutSetSummary is one logged set inside coach-context recent workouts.
type CoachWorkoutSetSummary struct {
	SetNumber int      `json:"set_number"`
	Reps      *int     `json:"reps,omitempty"`
	WeightKg  *float64 `json:"weight_kg,omitempty"`
	RPE       *float64 `json:"rpe,omitempty"`
	IsFailure bool     `json:"is_failure,omitempty"`
}

// CoachWorkoutExerciseSummary groups sets for one exercise on a completed workout.
type CoachWorkoutExerciseSummary struct {
	ExerciseID   string                   `json:"exercise_id"`
	ExerciseName string                   `json:"exercise_name"`
	Sets         []CoachWorkoutSetSummary `json:"sets"`
	BestSet      *SetLoadSummary          `json:"best_set,omitempty"`
	BestE1RMKg   float64                  `json:"best_e1rm_kg"`
	VolumeKg     float64                  `json:"volume_kg"`
}

// CoachRecentWorkout is a completed session with per-exercise set summaries (coach-context).
type CoachRecentWorkout struct {
	WorkoutID        string                        `json:"workout_id"`
	Name             *string                       `json:"name,omitempty"`
	RoutineID        *string                       `json:"routine_id,omitempty"`
	CompletedAt      string                        `json:"completed_at"`
	TotalVolumeKg    float64                       `json:"total_volume_kg"`
	DurationSeconds  int                           `json:"duration_seconds"`
	StrengthEloDelta *int                          `json:"strength_elo_delta,omitempty"`
	Exercises        []CoachWorkoutExerciseSummary `json:"exercises"`
}

// CoachContextResponse is GET /analytics/coach-context.
type CoachContextResponse struct {
	Profile             *CoachProfileView        `json:"profile,omitempty"`
	StrengthEloSummary  *CoachStrengthEloSummary `json:"strength_elo_summary,omitempty"`
	Sharpness           *SharpnessOverview       `json:"sharpness,omitempty"`
	Recovery            CoachRecoveryContext     `json:"recovery"`
	RecentWorkouts      []CoachRecentWorkout     `json:"recent_workouts"`
	ActiveRoutines      []CoachRoutine           `json:"active_routines"`
	ExerciseProgression []ExerciseListItem       `json:"exercise_progression"`
	RecentAIInsights    []ai.Insight             `json:"recent_ai_insights,omitempty"`
	PendingAIActions    []actionengine.Action    `json:"pending_ai_actions,omitempty"`
}

func coachProfileViewFrom(p *profile.Profile) *CoachProfileView {
	if p == nil {
		return nil
	}
	out := &CoachProfileView{
		UserID:                p.UserID,
		Age:                   p.Age,
		HeightCm:              p.HeightCm,
		WeightKg:              p.WeightKg,
		Gender:                p.Gender,
		Goal:                  p.FitnessGoal,
		Experience:            p.TrainingExperience,
		PreferredSplit:        p.PreferredSplit,
		InjuryNotes:           p.InjuryNotes,
		ActivityLevel:         p.ActivityLevel,
		StrengthElo:           p.StrengthElo,
		StrengthEloRank:       p.StrengthEloRank,
		StrengthEloChange30d:  p.StrengthEloChange30d,
		LastStrengthEloUpdate: p.LastStrengthEloUpdate,
	}
	if !p.UpdatedAt.IsZero() {
		t := p.UpdatedAt
		out.UpdatedAt = &t
	}
	return out
}

func eloDeltaFromStats(stats []byte) *int {
	if len(stats) == 0 {
		return nil
	}
	var fs workout.FinishStats
	if json.Unmarshal(stats, &fs) != nil || fs.StrengthElo == nil || fs.StrengthElo.Skipped {
		return nil
	}
	d := fs.StrengthElo.Delta
	return &d
}
