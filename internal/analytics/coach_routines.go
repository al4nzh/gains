package analytics

import "gainsai/internal/routine"

// CoachRoutine is a user routine with exercise rows keyed for coach / AI actions.
type CoachRoutine struct {
	RoutineID   string                 `json:"routine_id"`
	RoutineName string                 `json:"routine_name"`
	Exercises   []CoachRoutineExercise `json:"exercises"`
}

// CoachRoutineExercise is one line in a routine with stable IDs for proposed actions.
type CoachRoutineExercise struct {
	RoutineExerciseID string   `json:"routine_exercise_id"`
	ExerciseID        string   `json:"exercise_id"`
	ExerciseName      string   `json:"exercise_name"`
	Position          int      `json:"position"`
	TargetSets        *int     `json:"target_sets,omitempty"`
	TargetRepMin      *int     `json:"target_rep_min,omitempty"`
	TargetRepMax      *int     `json:"target_rep_max,omitempty"`
	RestSeconds       *int     `json:"rest_seconds,omitempty"`
}

func buildCoachRoutines(routines []routine.Routine) []CoachRoutine {
	out := make([]CoachRoutine, 0, len(routines))
	for _, r := range routines {
		cr := CoachRoutine{
			RoutineID:   r.ID,
			RoutineName: r.Name,
			Exercises:   make([]CoachRoutineExercise, 0, len(r.Exercises)),
		}
		for _, ex := range r.Exercises {
			cr.Exercises = append(cr.Exercises, CoachRoutineExercise{
				RoutineExerciseID: ex.ID,
				ExerciseID:        ex.ExerciseID,
				ExerciseName:      ex.ExerciseName,
				Position:          ex.Position,
				TargetSets:        ex.TargetSets,
				TargetRepMin:      ex.TargetRepMin,
				TargetRepMax:      ex.TargetRepMax,
				RestSeconds:       ex.RestSeconds,
			})
		}
		out = append(out, cr)
	}
	return out
}
