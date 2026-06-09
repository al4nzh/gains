package gymarchetype

import (
	"sort"
	"strings"
)

// SessionCategory classifies a workout session for archetype scoring.
type SessionCategory string

const (
	SessionPush    SessionCategory = "push"
	SessionPull    SessionCategory = "pull"
	SessionLegs    SessionCategory = "legs"
	SessionUpper   SessionCategory = "upper"
	SessionLower   SessionCategory = "lower"
	SessionFull    SessionCategory = "full"
	SessionGeneral SessionCategory = "general"
)

// SessionCategoryForWorkout infers session type from workout name and per-session muscle volume.
func SessionCategoryForWorkout(name string, volByMuscle map[string]float64) SessionCategory {
	if cat := classifyWorkoutName(name); cat != SessionGeneral {
		return cat
	}
	if len(volByMuscle) == 0 {
		return SessionGeneral
	}
	type pair struct {
		mg string
		v  float64
	}
	var ranked []pair
	for mg, v := range volByMuscle {
		ranked = append(ranked, pair{mg: mg, v: v})
	}
	sort.Slice(ranked, func(i, j int) bool { return ranked[i].v > ranked[j].v })
	if len(ranked) == 0 {
		return SessionGeneral
	}
	switch ranked[0].mg {
	case "back":
		return SessionPull
	case "chest", "shoulders":
		return SessionPush
	case "legs":
		return SessionLegs
	default:
		return SessionGeneral
	}
}

func classifyWorkoutName(name string) SessionCategory {
	n := strings.ToLower(strings.TrimSpace(name))
	switch {
	case strings.Contains(n, "push"):
		return SessionPush
	case strings.Contains(n, "pull"):
		return SessionPull
	case strings.Contains(n, "leg"):
		return SessionLegs
	case strings.Contains(n, "upper"):
		return SessionUpper
	case strings.Contains(n, "lower"):
		return SessionLower
	case strings.Contains(n, "full body"), strings.Contains(n, "full-body"), strings.Contains(n, "5×5"), strings.Contains(n, "5x5"):
		return SessionFull
	default:
		return SessionGeneral
	}
}
