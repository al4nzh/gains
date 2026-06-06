package aiquota

// Kind is one billable OpenAI action per user per day.
type Kind int

const (
	KindCoachMessage Kind = iota
	KindWorkoutAnalysis
	KindRoutineGeneration
	KindPhysiqueScan
)

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
