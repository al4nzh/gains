package analytics

import (
	"fmt"
	"math"
	"strings"
	"time"

	"gainsai/internal/routine"
	"gainsai/internal/workout"
)

// TrainTodayRecommendation is the home-tab "what to do now" card (GET /home).
type TrainTodayRecommendation struct {
	Action         string   `json:"action"`
	RoutineID      *string  `json:"routine_id,omitempty"`
	RoutineName    string   `json:"routine_name"`
	WorkoutID      *string  `json:"workout_id,omitempty"`
	SharpnessScore int      `json:"sharpness_score"`
	Reasons        []string `json:"reasons"`
}

type sessionCategory string

const (
	catPush    sessionCategory = "push"
	catPull    sessionCategory = "pull"
	catLegs    sessionCategory = "legs"
	catUpper   sessionCategory = "upper"
	catLower   sessionCategory = "lower"
	catFull    sessionCategory = "full"
	catGeneral sessionCategory = "general"
)

type routineCandidate struct {
	id       string
	name     string
	category sessionCategory
	lastDone *time.Time
}

func buildTrainToday(
	now time.Time,
	sharpness *SharpnessOverview,
	active *workout.Workout,
	routines []routine.Routine,
	recent []completedWorkoutRow,
) *TrainTodayRecommendation {
	score := 0
	if sharpness != nil {
		score = sharpness.Score
	}

	if active != nil {
		label := workoutDisplayLabel(active, routines)
		reasons := []string{"Workout in progress — pick up where you left off."}
		reasons = appendSharpnessReason(reasons, score)
		return &TrainTodayRecommendation{
			Action:         "resume_workout",
			WorkoutID:      &active.ID,
			RoutineName:    label,
			SharpnessScore: score,
			Reasons:        reasons,
		}
	}

	if len(routines) == 0 {
		reasons := []string{"Add a routine to get a daily training pick."}
		reasons = appendSharpnessReason(reasons, score)
		return &TrainTodayRecommendation{
			Action:         "browse_routines",
			RoutineName:    "Set up your program",
			SharpnessScore: score,
			Reasons:        reasons,
		}
	}

	candidates := make([]routineCandidate, 0, len(routines))
	for _, r := range routines {
		candidates = append(candidates, routineCandidate{
			id:       r.ID,
			name:     r.Name,
			category: classifyRoutineName(r.Name),
		})
	}

	lastByRoutine := map[string]time.Time{}
	lastByCategory := map[sessionCategory]categoryLastSession{}
	for _, row := range recent {
		rid := ""
		if row.RoutineID != nil {
			rid = *row.RoutineID
		}
		if rid != "" {
			if prev, ok := lastByRoutine[rid]; !ok || row.CompletedAt.After(prev) {
				lastByRoutine[rid] = row.CompletedAt
			}
		}
		cat, label := categoryForWorkoutRow(row, routines)
		prev := lastByCategory[cat]
		if prev.at.IsZero() || row.CompletedAt.After(prev.at) {
			lastByCategory[cat] = categoryLastSession{at: row.CompletedAt, label: label}
		}
	}

	for i := range candidates {
		if t, ok := lastByRoutine[candidates[i].id]; ok {
			candidates[i].lastDone = &t
		}
	}

	pick := pickTrainTodayCandidate(candidates, lastByCategory, now)
	if pick == nil {
		pick = &candidates[0]
	}

	reasons := buildTrainTodayReasons(pick.category, lastByCategory, now)
	reasons = appendSharpnessReason(reasons, score)

	rid := pick.id
	return &TrainTodayRecommendation{
		Action:         "start_routine",
		RoutineID:      &rid,
		RoutineName:    pick.name,
		SharpnessScore: score,
		Reasons:        reasons,
	}
}

type categoryLastSession struct {
	at    time.Time
	label string
}

func pickTrainTodayCandidate(
	candidates []routineCandidate,
	lastByCategory map[sessionCategory]categoryLastSession,
	now time.Time,
) *routineCandidate {
	lastCat, hasLast := mostRecentCategory(lastByCategory)

	var best *routineCandidate
	bestRotation := -1.0
	bestPref := -1

	for i := range candidates {
		c := &candidates[i]
		if !categoryReady(c.category, lastByCategory, now) {
			continue
		}
		rotation := rotationScore(c.lastDone, now)
		pref := 0
		if hasLast {
			pref = preferenceAfterLast(lastCat, c.category)
		}
		if rotation > bestRotation ||
			(rotation == bestRotation && pref > bestPref) {
			bestRotation = rotation
			bestPref = pref
			best = c
		}
	}

	if best != nil {
		return best
	}

	for i := range candidates {
		c := &candidates[i]
		rotation := rotationScore(c.lastDone, now)
		pref := 0
		if hasLast {
			pref = preferenceAfterLast(lastCat, c.category)
		}
		if rotation > bestRotation ||
			(rotation == bestRotation && pref > bestPref) {
			bestRotation = rotation
			bestPref = pref
			best = c
		}
	}
	return best
}

func mostRecentCategory(lastByCategory map[sessionCategory]categoryLastSession) (sessionCategory, bool) {
	var best sessionCategory
	var bestAt time.Time
	for cat, s := range lastByCategory {
		if s.at.IsZero() {
			continue
		}
		if bestAt.IsZero() || s.at.After(bestAt) {
			bestAt = s.at
			best = cat
		}
	}
	return best, !bestAt.IsZero()
}

func preferenceAfterLast(last, cand sessionCategory) int {
	switch last {
	case catLegs, catLower:
		switch cand {
		case catPull:
			return 3
		case catPush, catUpper:
			return 2
		case catLegs, catLower:
			return 0
		default:
			return 1
		}
	case catPush, catPull, catUpper:
		switch cand {
		case catLegs, catLower:
			return 3
		case catPush, catPull:
			return 0
		default:
			return 1
		}
	default:
		return 1
	}
}

func rotationScore(lastDone *time.Time, now time.Time) float64 {
	if lastDone == nil {
		return math.MaxFloat64
	}
	return now.Sub(*lastDone).Hours()
}

func categoryReady(cat sessionCategory, lastByCategory map[sessionCategory]categoryLastSession, now time.Time) bool {
	prev, ok := lastByCategory[cat]
	if !ok || prev.at.IsZero() {
		return true
	}
	return now.Sub(prev.at).Hours() >= recoveryHours(cat)
}

func buildTrainTodayReasons(
	recommended sessionCategory,
	lastByCategory map[sessionCategory]categoryLastSession,
	now time.Time,
) []string {
	var reasons []string
	if categoryReady(recommended, lastByCategory, now) {
		reasons = append(reasons, categoryRecoveredReason(recommended))
	}

	order := []sessionCategory{catLegs, catLower, catPush, catPull, catUpper, catFull}
	for _, cat := range order {
		if cat == recommended {
			continue
		}
		prev, ok := lastByCategory[cat]
		if !ok || prev.at.IsZero() {
			continue
		}
		if msg := categoryWaitReason(cat, prev.label, now.Sub(prev.at).Hours()); msg != "" {
			reasons = append(reasons, msg)
			break
		}
	}

	if len(reasons) == 0 {
		reasons = append(reasons, "Next up in your program rotation.")
	}
	return reasons
}

func appendSharpnessReason(reasons []string, score int) []string {
	if score <= 0 {
		return reasons
	}
	var tail string
	switch {
	case score >= 75:
		tail = "good to train"
	case score >= 60:
		tail = "okay to train"
	default:
		tail = "consider a lighter session"
	}
	return append(reasons, fmt.Sprintf("Sharpness: %d/100 — %s", score, tail))
}

func workoutDisplayLabel(w *workout.Workout, routines []routine.Routine) string {
	if w.RoutineID != nil {
		for _, r := range routines {
			if r.ID == *w.RoutineID {
				return r.Name
			}
		}
	}
	if w.Name != nil && strings.TrimSpace(*w.Name) != "" {
		return strings.TrimSpace(*w.Name)
	}
	return "Workout"
}

func categoryForWorkoutRow(row completedWorkoutRow, routines []routine.Routine) (sessionCategory, string) {
	if row.RoutineID != nil {
		for _, r := range routines {
			if r.ID == *row.RoutineID {
				return classifyRoutineName(r.Name), r.Name
			}
		}
	}
	if row.Name != nil && strings.TrimSpace(*row.Name) != "" {
		name := strings.TrimSpace(*row.Name)
		return classifyRoutineName(name), name
	}
	return catGeneral, "Last session"
}

func classifyRoutineName(name string) sessionCategory {
	n := strings.ToLower(strings.TrimSpace(name))
	switch {
	case strings.Contains(n, "push"):
		return catPush
	case strings.Contains(n, "pull"):
		return catPull
	case strings.Contains(n, "leg"):
		return catLegs
	case strings.Contains(n, "upper"):
		return catUpper
	case strings.Contains(n, "lower"):
		return catLower
	case strings.Contains(n, "full body"), strings.Contains(n, "full-body"), strings.Contains(n, "5×5"), strings.Contains(n, "5x5"):
		return catFull
	default:
		return catGeneral
	}
}

func recoveryHours(cat sessionCategory) float64 {
	switch cat {
	case catLegs, catLower, catFull:
		return 48
	default:
		return 24
	}
}

func categoryRecoveredReason(cat sessionCategory) string {
	switch cat {
	case catPull:
		return "Back and biceps are recovered"
	case catPush:
		return "Chest, shoulders, and triceps are recovered"
	case catLegs:
		return "Legs are recovered"
	case catLower:
		return "Lower body is recovered"
	case catUpper:
		return "Upper body is recovered"
	case catFull:
		return "Ready for another full-body session"
	default:
		return "Ready for your next session"
	}
}

func categoryWaitReason(cat sessionCategory, lastName string, hoursSince float64) string {
	need := recoveryHours(cat)
	if hoursSince >= need {
		return ""
	}
	remaining := int(math.Ceil(need - hoursSince))
	label := strings.TrimSpace(lastName)
	if label == "" {
		label = categoryDisplayName(cat)
	}
	if hoursSince < 36 {
		return fmt.Sprintf("%s trained recently — recover %dh more", label, remaining)
	}
	days := int(hoursSince / 24)
	if days < 1 {
		days = 1
	}
	return fmt.Sprintf("%s was %d day(s) ago — recover %dh more", label, days, remaining)
}

func categoryDisplayName(cat sessionCategory) string {
	switch cat {
	case catPull:
		return "Pull day"
	case catPush:
		return "Push day"
	case catLegs:
		return "Legs"
	case catLower:
		return "Lower body"
	case catUpper:
		return "Upper body"
	case catFull:
		return "Full body"
	default:
		return "Last session"
	}
}
