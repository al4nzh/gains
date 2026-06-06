package profile

import "time"

const (
	GoalMuscleGain     = "muscle_gain"
	GoalStrength       = "strength"
	GoalFatLoss        = "fat_loss"
	GoalGeneralFitness = "general_fitness"
)

const (
	ExperienceBeginner     = "beginner"
	ExperienceIntermediate = "intermediate"
	ExperienceAdvanced     = "advanced"
)

const (
	ActivitySedentary  = "sedentary"
	ActivityLight      = "light"
	ActivityModerate   = "moderate"
	ActivityActive     = "active"
	ActivityVeryActive = "very_active"
)

const (
	GenderFemale         = "female"
	GenderMale           = "male"
	GenderPreferNotToSay = "prefer_not_to_say"
)

type Profile struct {
	UserID                string     `json:"user_id"             db:"user_id"`
	Age                   *int       `json:"age,omitempty"       db:"age"`
	WeightKg              *float64   `json:"weight_kg,omitempty" db:"weight_kg"`
	HeightCm              *float64   `json:"height_cm,omitempty" db:"height_cm"`
	Gender                *string    `json:"gender,omitempty"    db:"gender"`
	FitnessGoal           *string    `json:"fitness_goal,omitempty"        db:"fitness_goal"`
	TrainingExperience    *string    `json:"training_experience,omitempty" db:"training_experience"`
	PreferredSplit        *string    `json:"preferred_split,omitempty"     db:"preferred_split"`
	TrainingDaysPerWeek   *int       `json:"training_days_per_week,omitempty" db:"training_days_per_week"`
	InjuryNotes           *string    `json:"injury_notes,omitempty"          db:"injury_notes"`
	ActivityLevel         *string    `json:"activity_level,omitempty"      db:"activity_level"`
	StrengthElo           *int       `json:"strength_elo,omitempty" db:"strength_elo"`
	StrengthEloRank       *string    `json:"strength_elo_rank,omitempty" db:"strength_elo_rank"`
	StrengthEloChange30d  *int       `json:"strength_elo_change_30d,omitempty" db:"strength_elo_change_30d"`
	LastStrengthEloUpdate *time.Time `json:"last_strength_elo_update,omitempty" db:"last_strength_elo_update"`
	CreatedAt             time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt             time.Time  `json:"updated_at" db:"updated_at"`
}
