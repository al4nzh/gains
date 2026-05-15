package analytics

type WorkoutSnapshot struct {
	WorkoutID       string  `json:"workout_id"`
	CompletedAt     string  `json:"completed_at"`
	TotalVolumeKg   float64 `json:"total_volume_kg"`
	DurationSeconds int     `json:"duration_seconds"`
	SetCount        int     `json:"set_count"`
}

type LastWorkoutComparison struct {
	Latest           *WorkoutSnapshot `json:"latest,omitempty"` // current session vs previous; omitted when first_session
	Previous         *WorkoutSnapshot `json:"previous,omitempty"`
	FirstSession     bool             `json:"first_session,omitempty"` // true when there is no older completed workout for the same routine (or same name when routine_id is null)
	VolumeDeltaPct   *float64         `json:"volume_delta_pct,omitempty"`
	DurationDeltaPct *float64         `json:"duration_delta_pct,omitempty"`
	SetCountDelta    *int             `json:"set_count_delta,omitempty"`
}

type SharpnessOverview struct {
	Score                     int     `json:"score"`
	Goal                      *string `json:"goal,omitempty"`
	Sleep01                   float64 `json:"sleep_0_1"`
	Energy01                  float64 `json:"energy_0_1"`
	Protein01                 float64 `json:"protein_alignment_0_1"`
	Calories01                float64 `json:"calorie_alignment_0_1"`
	TargetKcal                *int    `json:"target_calories_kcal,omitempty"`
	TargetProteinG            *int    `json:"target_protein_g,omitempty"`
	ActivityLevelResolved     string  `json:"activity_level_resolved"`     // after defaulting unset/invalid to moderate
	CalorieActivityMultiplier float64 `json:"calorie_activity_multiplier"` // applied to goal-based kcal/kg estimate
}

type WorkoutConsistency struct {
	CompletedLast28Days int     `json:"completed_last_28_days"`
	AvgPerWeek          float64 `json:"avg_per_week"`
}
