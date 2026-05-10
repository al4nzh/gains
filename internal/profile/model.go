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

type Profile struct {
	UserID             string    `json:"user_id"             db:"user_id"`
	Age                *int      `json:"age,omitempty"       db:"age"`
	WeightKg           *float64  `json:"weight_kg,omitempty" db:"weight_kg"`
	HeightCm           *float64  `json:"height_cm,omitempty" db:"height_cm"`
	Gender             *string   `json:"gender,omitempty"    db:"gender"`
	FitnessGoal        *string   `json:"fitness_goal,omitempty"        db:"fitness_goal"`
	TrainingExperience *string   `json:"training_experience,omitempty" db:"training_experience"`
	PreferredSplit     *string   `json:"preferred_split,omitempty"     db:"preferred_split"`
	InjuryNotes        *string   `json:"injury_notes,omitempty"          db:"injury_notes"`
	CreatedAt          time.Time `json:"created_at" db:"created_at"`
	UpdatedAt          time.Time `json:"updated_at" db:"updated_at"`
}
