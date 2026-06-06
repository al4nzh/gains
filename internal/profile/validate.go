package profile

import (
	"errors"
	"unicode/utf8"
)

// Validate checks profile field constraints (shared by HTTP API and AI action applier).
func Validate(p *Profile) error {
	if p.Age != nil {
		if *p.Age < 10 || *p.Age > 120 {
			return errors.New("age must be between 10 and 120")
		}
	}
	if p.HeightCm != nil {
		if *p.HeightCm < 50 || *p.HeightCm > 300 {
			return errors.New("height_cm must be between 50 and 300")
		}
	}
	if p.WeightKg != nil {
		if *p.WeightKg < 20 || *p.WeightKg > 400 {
			return errors.New("weight_kg must be between 20 and 400")
		}
	}
	if p.FitnessGoal != nil {
		if !isAllowedGoal(*p.FitnessGoal) {
			return errors.New("invalid goal: use muscle_gain, strength, fat_loss, or general_fitness")
		}
	}
	if p.TrainingExperience != nil {
		if !isAllowedExperience(*p.TrainingExperience) {
			return errors.New("invalid experience: use beginner, intermediate, or advanced")
		}
	}
	if p.PreferredSplit != nil && utf8.RuneCountInString(*p.PreferredSplit) > 128 {
		return errors.New("preferred_split must be at most 128 characters")
	}
	if p.InjuryNotes != nil && utf8.RuneCountInString(*p.InjuryNotes) > 2000 {
		return errors.New("injury_notes must be at most 2000 characters")
	}
	if p.ActivityLevel != nil && !isAllowedActivityLevel(*p.ActivityLevel) {
		return errors.New("invalid activity_level: use sedentary, light, moderate, active, or very_active")
	}
	if p.Gender != nil && !isAllowedGender(*p.Gender) {
		return errors.New("invalid gender: use female, male, or prefer_not_to_say")
	}
	if p.TrainingDaysPerWeek != nil {
		d := *p.TrainingDaysPerWeek
		if d < 2 || d > 5 {
			return errors.New("training_days_per_week must be between 2 and 5")
		}
	}
	return nil
}

func isAllowedGender(g string) bool {
	switch g {
	case GenderFemale, GenderMale, GenderPreferNotToSay:
		return true
	default:
		return false
	}
}

func isAllowedGoal(g string) bool {
	switch g {
	case GoalMuscleGain, GoalStrength, GoalFatLoss, GoalGeneralFitness:
		return true
	default:
		return false
	}
}

func isAllowedExperience(e string) bool {
	switch e {
	case ExperienceBeginner, ExperienceIntermediate, ExperienceAdvanced:
		return true
	default:
		return false
	}
}

func isAllowedActivityLevel(a string) bool {
	switch a {
	case ActivitySedentary, ActivityLight, ActivityModerate, ActivityActive, ActivityVeryActive:
		return true
	default:
		return false
	}
}
