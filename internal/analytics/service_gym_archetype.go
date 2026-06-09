package analytics

import (
	"context"
	"encoding/json"
	"strings"

	"gainsai/internal/gymarchetype"
	"gainsai/internal/profile"
	"gainsai/internal/workout"
)

const gymArchetypeAnalysisWorkouts = 36

// GymArchetype computes the user's gym archetype from workout history.
func (s *Service) GymArchetype(ctx context.Context, userID string) (gymarchetype.Response, error) {
	total, err := s.repo.CountCompletedWorkouts(ctx, userID)
	if err != nil {
		return gymarchetype.Response{}, err
	}

	rows, err := s.repo.ListCompletedWorkoutsRecent(ctx, userID, gymArchetypeAnalysisWorkouts)
	if err != nil {
		return gymarchetype.Response{}, err
	}
	setRows, err := s.repo.ListArchetypeSets(ctx, userID, gymArchetypeAnalysisWorkouts)
	if err != nil {
		return gymarchetype.Response{}, err
	}

	prof, err := s.profile.GetByUserID(ctx, userID)
	if err != nil {
		return gymarchetype.Response{}, err
	}

	workouts, sets := buildGymArchetypeInputs(rows, setRows)
	return gymarchetype.Calculate(profileToArchetype(prof), workouts, sets, total), nil
}

func profileToArchetype(p *profile.Profile) gymarchetype.Profile {
	if p == nil {
		return gymarchetype.Profile{}
	}
	return gymarchetype.Profile{
		FitnessGoal:         p.FitnessGoal,
		TrainingExperience:  p.TrainingExperience,
		TrainingDaysPerWeek: p.TrainingDaysPerWeek,
	}
}

func prCountFromStats(raw []byte) int {
	if len(raw) == 0 {
		return 0
	}
	var stats workout.FinishStats
	if err := json.Unmarshal(raw, &stats); err != nil {
		return 0
	}
	return len(stats.PRs)
}

func buildGymArchetypeInputs(rows []completedWorkoutRow, setRows []ArchetypeSetRow) ([]gymarchetype.Workout, []gymarchetype.Set) {
	volByWorkoutMuscle := map[string]map[string]float64{}
	sets := make([]gymarchetype.Set, 0, len(setRows))
	for _, s := range setRows {
		if s.Reps <= 0 || s.WeightKg <= 0 {
			continue
		}
		vol := float64(s.Reps) * s.WeightKg
		mg := strings.ToLower(strings.TrimSpace(s.MuscleGroup))
		if volByWorkoutMuscle[s.WorkoutID] == nil {
			volByWorkoutMuscle[s.WorkoutID] = map[string]float64{}
		}
		volByWorkoutMuscle[s.WorkoutID][mg] += vol
		sets = append(sets, gymarchetype.Set{
			WorkoutID:    s.WorkoutID,
			CompletedAt:  s.CompletedAt,
			ExerciseName: s.ExerciseName,
			MuscleGroup:  mg,
			Reps:         s.Reps,
			WeightKg:     s.WeightKg,
			VolumeKg:     vol,
		})
	}

	workouts := make([]gymarchetype.Workout, 0, len(rows))
	for _, row := range rows {
		vol := 0.0
		if row.TotalVolumeKg != nil {
			vol = *row.TotalVolumeKg
		}
		name := ""
		if row.Name != nil {
			name = *row.Name
		}
		workouts = append(workouts, gymarchetype.Workout{
			ID:            row.ID,
			CompletedAt:   row.CompletedAt,
			TotalVolumeKg: vol,
			PRCount:       prCountFromStats(row.Stats),
			Name:          name,
			SessionCat:    gymarchetype.SessionCategoryForWorkout(name, volByWorkoutMuscle[row.ID]),
		})
	}
	return workouts, sets
}
