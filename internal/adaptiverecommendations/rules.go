package adaptiverecommendations

import (
	"fmt"
	"math"
	"strings"

	"gainsai/internal/strength"
)

const (
	sharpnessLowThreshold   = 60
	sleepLowHours           = 6.0
	energyLowThreshold      = 2
	sharpnessGoodThreshold  = 75
	volumeSpikePct          = 0.25
	intensityReducePct      = 7.5
	progressionMinSessions  = 3
)

func buildRecommendations(in evalInput, scope string) []Recommendation {
	var out []Recommendation
	seen := map[string]struct{}{}

	add := func(r Recommendation) {
		if _, ok := seen[r.ID]; ok {
			return
		}
		seen[r.ID] = struct{}{}
		out = append(out, r)
	}

	lowReadiness := (in.HasSharpness && in.SharpnessScore < sharpnessLowThreshold) ||
		(in.HasSleep && in.LatestSleepHours < sleepLowHours) ||
		(in.HasEnergy && in.LatestEnergy <= energyLowThreshold)

	if lowReadiness {
		reason := readinessReason(in)
		for _, ex := range in.RoutineExercises {
			if !ex.IsAccessory {
				continue
			}
			mg := ex.MuscleGroup
			if mg == "" {
				mg = "general"
			}
			id := recID(TypeReduceVolume, ex.RoutineExerciseID)
			delta := -1
			add(Recommendation{
				ID:                      id,
				Type:                    TypeReduceVolume,
				Scope:                   scope,
				TargetExerciseID:        strPtr(ex.ExerciseID),
				TargetRoutineExerciseID: strPtr(ex.RoutineExerciseID),
				TargetMuscleGroup:       strPtr(mg),
				Reason:                  reason,
				Message:                 fmt.Sprintf("Sharpness is low today. Reduce %s accessory volume by 1 set.", muscleLabel(mg)),
				SuggestedChange:         SuggestedChange{SetsDelta: &delta},
				Confidence:              "medium",
			})
		}
	}

	if shoulderConcern(in.InjuryText) {
		for _, ex := range in.RoutineExercises {
			altName, altID, ok := saferShoulderAlternative(ex.ExerciseName, in.ExerciseMeta)
			if !ok {
				continue
			}
			id := recID(TypeSwapExercise, ex.ExerciseID)
			add(Recommendation{
				ID:                      id,
				Type:                    TypeSwapExercise,
				Scope:                   scope,
				TargetExerciseID:        strPtr(ex.ExerciseID),
				TargetRoutineExerciseID: strPtr(ex.RoutineExerciseID),
				TargetMuscleGroup:       strPtrOrNil(ex.MuscleGroup),
				Reason:                  "Shoulder discomfort or injury noted",
				Message:                 fmt.Sprintf("Recent shoulder concern detected. Consider swapping %s for %s.", ex.ExerciseName, altName),
				SuggestedChange: SuggestedChange{
					ReplaceExerciseID:   strPtr(altID),
					ReplaceExerciseName: strPtr(altName),
				},
				Confidence: "medium",
			})
		}
	}

	for exID, trend := range in.ExerciseTrends {
		if trend != "down" {
			continue
		}
		if in.ExerciseSessionCount[exID] < progressionMinSessions {
			continue
		}
		meta, ok := in.ExerciseMeta[exID]
		if !ok {
			continue
		}
		var reID, mg *string
		for _, ex := range in.RoutineExercises {
			if ex.ExerciseID == exID {
				reID = strPtr(ex.RoutineExerciseID)
				if ex.MuscleGroup != "" {
					mg = strPtr(ex.MuscleGroup)
				}
				break
			}
		}
		if reID == nil {
			continue
		}
		pct := -intensityReducePct
		id := recID(TypeReduceIntensity, exID)
		msg := fmt.Sprintf("Recent %s performance is slipping on this routine. Try reducing intensity by about 5–10%% today.", meta.Name)
		for _, ex := range in.RoutineExercises {
			if ex.ExerciseID != exID {
				continue
			}
			if w, r, ok := baseLoadForExercise(ex, in.LastBestLoad); ok {
				reduced := w * (1 + pct/100)
				if r > 0 {
					msg = fmt.Sprintf("Recent %s is slipping on this routine. Consider %d × %.1f kg (down from %d × %.1f).", meta.Name, r, reduced, r, w)
				} else {
					msg = fmt.Sprintf("Recent %s is slipping on this routine. Consider about %.1f kg (down from %.1f).", meta.Name, reduced, w)
				}
			}
			break
		}
		add(Recommendation{
			ID:                      id,
			Type:                    TypeReduceIntensity,
			Scope:                   scope,
			TargetExerciseID:        strPtr(exID),
			TargetRoutineExerciseID: reID,
			TargetMuscleGroup:       mg,
			Reason:                  fmt.Sprintf("%s e1RM has trended down on recent sessions with this routine", meta.Name),
			Message:                 msg,
			SuggestedChange:         SuggestedChange{WeightDeltaPct: &pct},
			Confidence:              "medium",
		})
	}

	if lowReadiness || (in.HasEnergy && in.LatestEnergy <= energyLowThreshold) {
		routineMuscles := routineMuscleGroups(in.RoutineExercises)
		for mg, cur := range in.WeeklyVolByMuscle {
			if mg == "" {
				continue
			}
			if _, ok := routineMuscles[mg]; !ok {
				continue
			}
			prior := in.PriorVolByMuscle[mg]
			if prior <= 0 || cur <= prior*(1+volumeSpikePct) {
				continue
			}
			id := recID(TypeReduceMuscleVolume, mg)
			delta := -1
			add(Recommendation{
				ID:                id,
				Type:              TypeReduceMuscleVolume,
				Scope:             scope,
				TargetMuscleGroup: strPtr(mg),
				Reason:            fmt.Sprintf("%s volume on this routine is up while recovery looks low", muscleLabel(mg)),
				Message:           fmt.Sprintf("Recovery is low and %s volume jumped on this routine. Consider trimming 1 accessory set.", muscleLabel(mg)),
				SuggestedChange:   SuggestedChange{SetsDelta: &delta},
				Confidence:        "low",
			})
		}
	}

	goodRecovery := in.HasSharpness && in.SharpnessScore >= sharpnessGoodThreshold &&
		(!in.HasEnergy || in.LatestEnergy >= 4)

	if goodRecovery {
		for _, ex := range in.RoutineExercises {
			if in.ExerciseTrends[ex.ExerciseID] != "up" {
				continue
			}
			baseWeight, baseReps, ok := baseLoadForExercise(ex, in.LastBestLoad)
			if !ok {
				continue
			}
			delta := 2.5
			suggested := baseWeight + delta
			id := recID(TypeIncreaseWeight, ex.ExerciseID)
			mg := ex.MuscleGroup
			msg := fmt.Sprintf(
				"Recovery is solid and %s is trending up on this routine. Try %.1f kg (+%.1f from last time) if it moves well.",
				ex.ExerciseName, suggested, delta,
			)
			if baseReps > 0 {
				msg = fmt.Sprintf(
					"Recovery is solid and %s is trending up on this routine. Try %d × %.1f kg (was %d × %.1f) if it moves well.",
					ex.ExerciseName, baseReps, suggested, baseReps, baseWeight,
				)
			}
			add(Recommendation{
				ID:                      id,
				Type:                    TypeIncreaseWeight,
				Scope:                   scope,
				TargetExerciseID:        strPtr(ex.ExerciseID),
				TargetRoutineExerciseID: strPtr(ex.RoutineExerciseID),
				TargetMuscleGroup:       strPtrOrNil(mg),
				Reason:                  "Recovery looks good and performance is improving on this routine",
				Message:                 msg,
				SuggestedChange:         SuggestedChange{WeightDeltaKg: &delta},
				Confidence:              "medium",
			})
		}
	}

	return out
}

func readinessReason(in evalInput) string {
	var parts []string
	if in.HasSharpness && in.SharpnessScore < sharpnessLowThreshold {
		parts = append(parts, fmt.Sprintf("sharpness %d", in.SharpnessScore))
	}
	if in.HasSleep && in.LatestSleepHours < sleepLowHours {
		parts = append(parts, fmt.Sprintf("sleep %.1fh", in.LatestSleepHours))
	}
	if in.HasEnergy && in.LatestEnergy <= energyLowThreshold {
		parts = append(parts, fmt.Sprintf("energy %d/5", in.LatestEnergy))
	}
	if len(parts) == 0 {
		return "Low readiness today"
	}
	return "Low readiness today (" + strings.Join(parts, ", ") + ")"
}

func shoulderConcern(text string) bool {
	t := strings.ToLower(text)
	keywords := []string{"shoulder", "rotator", "impingement", "pec tear", "discomfort", "pain", "injury", "hurt", "sore shoulder"}
	for _, k := range keywords {
		if strings.Contains(t, k) {
			return true
		}
	}
	return false
}

func saferShoulderAlternative(name string, meta map[string]exerciseMeta) (altName, altID string, ok bool) {
	n := strings.TrimSpace(strings.ToLower(name))
	var want string
	switch n {
	case "bench press", "incline bench press":
		want = "Dumbbell Bench Press"
	case "ohp", "overhead press", "arnold press":
		want = "Dumbbell Shoulder Press"
	default:
		if _, isBench := strength.BenchmarkLiftFromExerciseName(name); isBench && strings.Contains(n, "press") {
			want = "Dumbbell Bench Press"
		} else {
			return "", "", false
		}
	}
	for id, m := range meta {
		if strings.EqualFold(m.Name, want) {
			return m.Name, id, true
		}
	}
	return want, "", true // name-only fallback; apply resolves id
}

func isBenchmarkExerciseName(name string) bool {
	_, ok := strength.BenchmarkLiftFromExerciseName(name)
	return ok
}

func classifyRoutineExercises(rows []routineExerciseEval) []routineExerciseEval {
	seenPrimaryMuscle := map[string]bool{}
	out := make([]routineExerciseEval, len(rows))
	copy(out, rows)
	for i := range out {
		ex := &out[i]
		if isBenchmarkExerciseName(ex.ExerciseName) {
			ex.IsAccessory = false
			if ex.MuscleGroup != "" {
				seenPrimaryMuscle[ex.MuscleGroup] = true
			}
			continue
		}
		if ex.MuscleGroup != "" && !seenPrimaryMuscle[ex.MuscleGroup] {
			seenPrimaryMuscle[ex.MuscleGroup] = true
			ex.IsAccessory = false
			continue
		}
		sets := 0
		if ex.TargetSets != nil {
			sets = *ex.TargetSets
		}
		ex.IsAccessory = sets >= 2
	}
	return out
}

func recID(t RecommendationType, key string) string {
	return fmt.Sprintf("%s:%s", t, key)
}

func strPtr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func strPtrOrNil(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func muscleLabel(mg string) string {
	if mg == "" {
		return "target"
	}
	return mg
}

func baseLoadForExercise(ex routineExerciseEval, last map[string]lastSetLoadEval) (weight float64, reps int, ok bool) {
	if load, has := last[ex.ExerciseID]; has && load.WeightKg > 0 {
		return load.WeightKg, load.Reps, true
	}
	if ex.TargetWeightKg != nil && *ex.TargetWeightKg > 0 {
		return *ex.TargetWeightKg, 0, true
	}
	return 0, 0, false
}

func routineMuscleGroups(exercises []routineExerciseEval) map[string]struct{} {
	out := map[string]struct{}{}
	for _, ex := range exercises {
		if ex.MuscleGroup == "" {
			continue
		}
		out[ex.MuscleGroup] = struct{}{}
	}
	return out
}

func roundVol(v float64) float64 {
	return math.Round(v*100) / 100
}
