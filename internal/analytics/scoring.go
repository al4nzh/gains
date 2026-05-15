package analytics

import (
	"math"
	"strings"

	"gainsai/internal/profile"
)

// nutritionTargets returns rough daily kcal (per kg BW) and protein (g per kg BW) from profile goal.
func nutritionTargets(goal *string) (kcalPerKg float64, proteinGPerKg float64) {
	if goal == nil {
		return 31, 1.5
	}
	switch *goal {
	case profile.GoalMuscleGain:
		return 34, 1.8
	case profile.GoalStrength:
		return 33, 1.7
	case profile.GoalFatLoss:
		return 27, 1.8
	case profile.GoalGeneralFitness:
		return 31, 1.4
	default:
		return 31, 1.5
	}
}

// resolveActivityLevelForTargets maps stored profile value (or nil) to a level used for calorie scaling.
// Unknown or empty strings fall back to moderate.
func resolveActivityLevelForTargets(al *string) string {
	if al == nil {
		return profile.ActivityModerate
	}
	s := strings.TrimSpace(*al)
	switch s {
	case profile.ActivitySedentary, profile.ActivityLight, profile.ActivityModerate,
		profile.ActivityActive, profile.ActivityVeryActive:
		return s
	default:
		return profile.ActivityModerate
	}
}

// calorieActivityMultiplier scales the goal-based kcal/kg estimate by self-reported lifestyle activity
// (not workout volume or session counts).
func calorieActivityMultiplier(level string) float64 {
	switch level {
	case profile.ActivitySedentary:
		return 0.93
	case profile.ActivityLight:
		return 0.97
	case profile.ActivityModerate:
		return 1.0
	case profile.ActivityActive:
		return 1.06
	case profile.ActivityVeryActive:
		return 1.12
	default:
		return 1.0
	}
}

// sharpnessFromAverages maps 7d averages to a 0–100 score using goal-adjusted calorie + protein alignment.
// Calorie target uses profile activity_level (default moderate when unset).
func sharpnessFromAverages(avgSleep, avgEnergy, avgCal, avgProtein float64, days int, weightKg float64, goal *string, activityLevel *string) *SharpnessOverview {
	if days < 1 {
		return nil
	}
	resolved := resolveActivityLevelForTargets(activityLevel)
	mult := calorieActivityMultiplier(resolved)
	multRounded := math.Round(mult*100) / 100

	sleep01 := math.Min(avgSleep/8.0, 1.0)
	if sleep01 < 0 {
		sleep01 = 0
	}
	energy01 := math.Max(0, math.Min(avgEnergy/5.0, 1.0))

	kcalPerKg, protPerKg := nutritionTargets(goal)
	targetKcal := int(math.Round(weightKg * kcalPerKg * mult))
	targetProt := int(math.Round(weightKg * protPerKg))
	if targetKcal < 1200 {
		targetKcal = 1200
	}
	if targetProt < 50 {
		targetProt = 50
	}

	tk := float64(targetKcal)
	tp := float64(targetProt)

	protein01 := math.Min(avgProtein/tp, 1.15)
	if protein01 > 1 {
		protein01 = 1
	}

	cal01 := calorieAlignment01(avgCal, tk, goal)

	wSleep, wEnergy, wProt, wCal := 0.28, 0.22, 0.28, 0.22
	raw := wSleep*sleep01 + wEnergy*energy01 + wProt*protein01 + wCal*cal01
	score := int(math.Round(100 * math.Max(0, math.Min(1, raw))))
	g := goal
	tkOut := targetKcal
	return &SharpnessOverview{
		Score:                     score,
		Goal:                      g,
		Sleep01:                   sleep01,
		Energy01:                  energy01,
		Protein01:                 protein01,
		Calories01:                cal01,
		TargetKcal:                &tkOut,
		TargetProteinG:            &targetProt,
		ActivityLevelResolved:     resolved,
		CalorieActivityMultiplier: multRounded,
	}
}

func calorieAlignment01(avgCal, target float64, goal *string) float64 {
	if target <= 0 {
		return 0.5
	}
	ratio := avgCal / target
	// muscle / strength: slightly above target still "ok"; fat_loss: prefer at or below
	if goal != nil && (*goal == profile.GoalFatLoss) {
		if ratio <= 1.0 {
			return math.Min(1, ratio+0.15) // small cushion
		}
		over := ratio - 1.0
		return math.Max(0, 1-2*over)
	}
	// surplus-tolerant goals
	if ratio >= 0.92 && ratio <= 1.12 {
		return 1.0
	}
	if ratio < 0.92 {
		return math.Max(0, ratio/0.92)
	}
	over := ratio - 1.12
	return math.Max(0, 1-over*2)
}
