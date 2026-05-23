package ai

import (
	"strings"
	"unicode/utf8"

	"gainsai/internal/actionengine"
	"gainsai/internal/exercise"
)

type routineGenValidateResult struct {
	Draft         storedRoutineDraft
	Clarification *actionengine.Clarification
}

func validateAndResolveRoutineDraft(raw *llmRoutineGenOutput, catalog []exercise.Exercise, resolve func(name string) (string, []exercise.Exercise, error)) routineGenValidateResult {
	out := routineGenValidateResult{}
	if raw == nil {
		out.Clarification = &actionengine.Clarification{
			Required: true,
			Message:  "Could not parse a routine plan from the model.",
		}
		return out
	}

	title := strings.TrimSpace(raw.Title)
	if title == "" {
		title = "Generated training plan"
	}
	if utf8.RuneCountInString(title) > 200 {
		title = string([]rune(title)[:200])
	}

	if len(raw.Routines) == 0 {
		out.Clarification = &actionengine.Clarification{
			Required: true,
			Message:  "No routines were generated. Try a clearer request.",
		}
		return out
	}
	if len(raw.Routines) > maxRoutinesPerDraft {
		raw.Routines = raw.Routines[:maxRoutinesPerDraft]
	}

	routines := make([]DraftRoutine, 0, len(raw.Routines))
	var allAmbiguous []actionengine.ExerciseMatch

	for _, rr := range raw.Routines {
		name := strings.TrimSpace(rr.Name)
		if name == "" {
			continue
		}
		if utf8.RuneCountInString(name) > 200 {
			name = string([]rune(name)[:200])
		}
		var desc *string
		if rr.Description != nil {
			d := strings.TrimSpace(*rr.Description)
			if d != "" {
				if utf8.RuneCountInString(d) > 500 {
					d = string([]rune(d)[:500])
				}
				desc = &d
			}
		}

		exs := rr.Exercises
		if len(exs) > maxExercisesPerRoutine {
			exs = exs[:maxExercisesPerRoutine]
		}
		if len(exs) == 0 {
			continue
		}

		draftExs := make([]DraftExercise, 0, len(exs))
		for _, le := range exs {
			exName := strings.TrimSpace(le.ExerciseName)
			if exName == "" {
				continue
			}
			id, ambiguous, err := resolve(exName)
			if err != nil {
				continue
			}
			if len(ambiguous) > 0 {
				for _, a := range ambiguous {
					allAmbiguous = append(allAmbiguous, actionengine.ExerciseMatch{
						ExerciseID:   a.ID,
						ExerciseName: a.Name,
					})
				}
				allAmbiguous = append(allAmbiguous, actionengine.ExerciseMatch{
					ExerciseID:   "",
					ExerciseName: exName,
				})
				continue
			}
			if id == "" {
				allAmbiguous = append(allAmbiguous, actionengine.ExerciseMatch{
					ExerciseID:   "",
					ExerciseName: exName,
				})
				continue
			}

			canonName := exName
			for _, c := range catalog {
				if c.ID == id {
					canonName = c.Name
					break
				}
			}

			if err := validateDraftExerciseFields(le.TargetSets, le.TargetRepMin, le.TargetRepMax, le.RestSeconds); err != nil {
				continue
			}

			var notes *string
			if le.Notes != nil {
				n := strings.TrimSpace(*le.Notes)
				if n != "" {
					if utf8.RuneCountInString(n) > 500 {
						n = string([]rune(n)[:500])
					}
					notes = &n
				}
			}

			draftExs = append(draftExs, DraftExercise{
				ExerciseID:   id,
				ExerciseName: canonName,
				TargetSets:   le.TargetSets,
				TargetRepMin: le.TargetRepMin,
				TargetRepMax: le.TargetRepMax,
				RestSeconds:  le.RestSeconds,
				Notes:        notes,
			})
		}

		if len(draftExs) == 0 {
			continue
		}
		routines = append(routines, DraftRoutine{
			Name:        name,
			Description: desc,
			Exercises:   draftExs,
		})
	}

	if len(routines) == 0 {
		out.Clarification = &actionengine.Clarification{
			Required:        true,
			Message:         "No valid exercises could be matched to the catalog.",
			PossibleMatches: dedupeMatches(allAmbiguous),
		}
		return out
	}

	if len(allAmbiguous) > 0 {
		out.Clarification = &actionengine.Clarification{
			Required:        true,
			Message:         "Some exercise names were ambiguous or not found. Use exact catalog names and try again.",
			PossibleMatches: dedupeMatches(allAmbiguous),
		}
		return out
	}

	out.Draft = storedRoutineDraft{Title: title, Routines: routines}
	return out
}

func validateDraftExerciseFields(sets, repMin, repMax, rest *int) error {
	if sets != nil && (*sets < 1 || *sets > 10) {
		return ErrActionValidation
	}
	if repMin != nil && repMax != nil {
		if *repMin < 1 || *repMax < 1 || *repMin > *repMax || *repMax > 50 {
			return ErrActionValidation
		}
	}
	if rest != nil && (*rest < 0 || *rest > 600) {
		return ErrActionValidation
	}
	return nil
}

func dedupeMatches(in []actionengine.ExerciseMatch) []actionengine.ExerciseMatch {
	seen := make(map[string]struct{})
	out := make([]actionengine.ExerciseMatch, 0, len(in))
	for _, m := range in {
		key := m.ExerciseID + "|" + m.ExerciseName
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		out = append(out, m)
	}
	if len(out) > 20 {
		out = out[:20]
	}
	return out
}

func catalogEntries(list []exercise.Exercise) []exerciseLibraryEntry {
	out := make([]exerciseLibraryEntry, 0, len(list))
	for _, e := range list {
		out = append(out, exerciseLibraryEntry{
			ExerciseID:    e.ID,
			ExerciseName:  e.Name,
			PrimaryMuscle: e.MuscleGroup,
			Equipment:     e.Equipment,
		})
	}
	return out
}
