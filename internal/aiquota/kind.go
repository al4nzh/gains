package aiquota

// Kind is one billable OpenAI action per user per day.
type Kind int

const (
	KindCoachMessage Kind = iota
	KindWorkoutAnalysis
	KindRoutineGeneration
	KindPhysiqueScan
)

// RequiresPremium is true for billable OpenAI features (freemium paywall).
func (k Kind) RequiresPremium() bool {
	switch k {
	case KindCoachMessage, KindWorkoutAnalysis, KindRoutineGeneration, KindPhysiqueScan:
		return true
	default:
		return false
	}
}

func (k Kind) column() string {
	switch k {
	case KindCoachMessage:
		return "coach_messages"
	case KindWorkoutAnalysis:
		return "workout_analyses"
	case KindRoutineGeneration:
		return "routine_generations"
	case KindPhysiqueScan:
		return "physique_scans"
	default:
		return ""
	}
}
