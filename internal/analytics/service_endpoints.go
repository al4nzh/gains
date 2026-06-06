package analytics

import (
	"context"
	"encoding/json"
	"errors"
	"math"
	"sort"
	"time"

	"gainsai/internal/recovery"
	"gainsai/internal/strength"
	"gainsai/internal/workout"
)

// Home returns the lightweight home tab payload.
func (s *Service) Home(ctx context.Context, userID string) (*HomeResponse, error) {
	now := time.Now().UTC()
	from7 := now.AddDate(0, 0, -7).Truncate(24 * time.Hour)
	from28 := now.AddDate(0, 0, -28).Truncate(24 * time.Hour)

	vol7, err := s.repo.SumVolumeCompletedSince(ctx, userID, from7)
	if err != nil {
		return nil, err
	}
	wrows, err := s.repo.ListCompletedWorkoutsRecent(ctx, userID, 36)
	if err != nil {
		return nil, err
	}
	n28, err := s.repo.CountCompletedSince(ctx, userID, from28)
	if err != nil {
		return nil, err
	}
	dates, err := s.repo.ListDistinctCompletionDatesUTC(ctx, userID, 120)
	if err != nil {
		return nil, err
	}
	checkins, err := s.recovery.ListByDateRange(ctx, userID, from7, now.Truncate(24*time.Hour))
	if err != nil {
		return nil, err
	}
	prof, err := s.profile.GetByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}

	var eloPercentile *int
	if prof.StrengthElo != nil {
		if p, ok, err := s.profile.StrengthEloPercentile(ctx, *prof.StrengthElo, prof.Gender); err != nil {
			return nil, err
		} else if ok {
			eloPercentile = &p
		}
	}

	out := &HomeResponse{
		StrengthElo:            prof.StrengthElo,
		StrengthEloRank:        prof.StrengthEloRank,
		StrengthEloPercentile:  eloPercentile,
		EloChange30d:           prof.StrengthEloChange30d,
		WeeklyVolumeKg:         math.Round(vol7*100) / 100,
		WeeklyVolumeWindowDays: 7,
		WorkoutConsistency: WorkoutConsistency{
			CompletedLast28Days: n28,
			AvgPerWeek:          math.Round(float64(n28)/4.0*100) / 100,
		},
		StreakDays: streakFromDistinctDescDates(dates, now),
	}
	if len(wrows) > 0 {
		snap := snapshotFromRow(wrows[0])
		out.LatestWorkout = &snap
	}
	out.Sharpness = sharpnessForHome(checkins, prof)

	routines, err := s.routineRepo.ListRoutinesByUser(ctx, userID)
	if err != nil {
		return nil, err
	}
	active, err := s.workoutRepo.GetActiveWorkoutForUser(ctx, userID)
	if err != nil {
		return nil, err
	}
	out.TrainToday = buildTrainToday(now, out.Sharpness, active, routines, wrows)
	return out, nil
}

// Exercises returns the progress-tab exercise list.
func (s *Service) Exercises(ctx context.Context, userID string) (*ExercisesListResponse, error) {
	rows, err := s.repo.ListRecentCompletedWorkoutSetsForProgression(ctx, userID, exerciseListWindowWorkouts)
	if err != nil {
		return nil, err
	}
	life, err := s.repo.ListLifetimeBestSetPerExercise(ctx, userID)
	if err != nil {
		return nil, err
	}
	lifetime := make(map[string]LifetimeBestSet, len(life))
	for _, lb := range life {
		lifetime[lb.ExerciseID] = lb
	}
	return &ExercisesListResponse{Exercises: BuildExerciseListItems(rows, lifetime)}, nil
}

// ExerciseDetail returns per-workout history for one exercise.
func (s *Service) ExerciseDetail(ctx context.Context, userID, exerciseID string) (*ExerciseDetailResponse, error) {
	flat, err := s.repo.ListExerciseDetailRows(ctx, userID, exerciseID, 60)
	if err != nil {
		return nil, err
	}
	out := BuildExerciseDetailResponse(exerciseID, flat)
	lb, err := s.repo.GetLifetimeBestSetForExercise(ctx, userID, exerciseID)
	if err != nil {
		return nil, err
	}
	applyLifetimeBestToDetail(out, lb)
	return out, nil
}

// WorkoutContext returns structured data for analyze-workout / AI.
func (s *Service) WorkoutContext(ctx context.Context, userID, workoutID string) (*WorkoutContextResponse, error) {
	w, err := s.workoutRepo.GetWorkoutForUser(ctx, userID, workoutID)
	if err != nil {
		if errors.Is(err, workout.ErrNotFound) {
			return nil, err
		}
		return nil, err
	}
	sets, err := s.workoutRepo.ListSetsForWorkout(ctx, workoutID)
	if err != nil {
		return nil, err
	}
	w.Sets = sets

	now := time.Now().UTC()
	from7 := now.AddDate(0, 0, -7).Truncate(24 * time.Hour)
	checkins, err := s.recovery.ListByDateRange(ctx, userID, from7, now.Truncate(24*time.Hour))
	if err != nil {
		return nil, err
	}
	prof, err := s.profile.GetByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}

	out := &WorkoutContextResponse{
		Workout:                w,
		ProfileBasics:          workoutContextProfileBasicsFrom(prof),
		Sharpness:              sharpnessFromCheckins(checkins, prof),
		RecentRecoveryCheckins: toRecoveryLites(checkins),
		StrengthEloDelta:       eloDeltaFromStats(w.Stats),
	}

	if len(w.Stats) > 0 {
		var fs workout.FinishStats
		if json.Unmarshal(w.Stats, &fs) == nil {
			out.PRs = fs.PRs
		}
	}

	const workoutContextRecentLimit = 8
	wrows, err := s.repo.ListCompletedWorkoutsRecent(ctx, userID, 12)
	if err != nil {
		return nil, err
	}
	for _, row := range wrows {
		if row.ID == w.ID {
			continue
		}
		setsR, err := s.workoutRepo.ListSetsForWorkout(ctx, row.ID)
		if err != nil {
			return nil, err
		}
		out.RelevantRecentWorkouts = append(out.RelevantRecentWorkouts, buildWorkoutContextRecentWorkout(row, setsR))
		if len(out.RelevantRecentWorkouts) >= workoutContextRecentLimit {
			break
		}
	}

	if w.CompletedAt != nil {
		cur := workoutToCompletedRow(w)
		prev, err := s.repo.GetPreviousMatchingCompleted(ctx, userID, *w.CompletedAt, w.RoutineID, w.Name)
		if err != nil {
			return nil, err
		}
		out.PreviousSameRoutine = buildLastWorkoutComparison(cur, prev)
		if prev != nil {
			prevSets, err := s.workoutRepo.ListSetsForWorkout(ctx, prev.ID)
			if err != nil {
				return nil, err
			}
			out.ExerciseComparisons = exerciseComparisons(cur, sets, prev, prevSets)
		}
	}
	return out, nil
}

// WorkoutContextJSON is the canonical JSON sent to POST /ai/analyze-workout: same object as
// GET /analytics/workouts/:workoutId/context, pretty-printed for LLM prompts.
func (s *Service) WorkoutContextJSON(ctx context.Context, userID, workoutID string) ([]byte, error) {
	wctx, err := s.WorkoutContext(ctx, userID, workoutID)
	if err != nil {
		return nil, err
	}
	return json.MarshalIndent(wctx, "", "  ")
}

// CoachContextJSON is the canonical JSON for POST /ai/chat (same payload as GET /analytics/coach-context).
func (s *Service) CoachContextJSON(ctx context.Context, userID string) ([]byte, error) {
	ctxPayload, err := s.CoachContext(ctx, userID)
	if err != nil {
		return nil, err
	}
	return json.MarshalIndent(ctxPayload, "", "  ")
}

func exerciseComparisons(cur completedWorkoutRow, curSets []workout.SetOut, prev *completedWorkoutRow, prevSets []workout.SetOut) []WorkoutContextExerciseCompare {
	curByEx := map[string]float64{}
	curVol := map[string]float64{}
	nameByEx := map[string]string{}
	for _, so := range curSets {
		s := so.Set
		if s.Reps != nil && s.WeightKg != nil && *s.Reps > 0 && *s.WeightKg > 0 {
			e := strength.Estimate1RMBrzycki(*s.WeightKg, *s.Reps)
			if e > curByEx[s.ExerciseID] {
				curByEx[s.ExerciseID] = e
			}
			curVol[s.ExerciseID] += float64(*s.Reps) * *s.WeightKg
			if so.ExerciseName != "" {
				nameByEx[s.ExerciseID] = so.ExerciseName
			}
		}
	}
	prevByEx := map[string]float64{}
	prevVol := map[string]float64{}
	for _, so := range prevSets {
		s := so.Set
		if s.Reps != nil && s.WeightKg != nil && *s.Reps > 0 && *s.WeightKg > 0 {
			e := strength.Estimate1RMBrzycki(*s.WeightKg, *s.Reps)
			if e > prevByEx[s.ExerciseID] {
				prevByEx[s.ExerciseID] = e
			}
			prevVol[s.ExerciseID] += float64(*s.Reps) * *s.WeightKg
			if so.ExerciseName != "" {
				nameByEx[s.ExerciseID] = so.ExerciseName
			}
		}
	}
	var keys []string
	for id := range curByEx {
		keys = append(keys, id)
	}
	sort.Strings(keys)
	out := make([]WorkoutContextExerciseCompare, 0, len(keys))
	for _, id := range keys {
		cE := curByEx[id]
		cV := curVol[id]
		nm := nameByEx[id]
		cmp := WorkoutContextExerciseCompare{
			ExerciseID:      id,
			ExerciseName:    nm,
			CurrentE1RMKg:   math.Round(cE*100) / 100,
			CurrentVolumeKg: math.Round(cV*100) / 100,
		}
		if pE, ok := prevByEx[id]; ok {
			pe := math.Round(pE*100) / 100
			cmp.PreviousE1RMKg = &pe
			d := math.Round((cE-pE)*100) / 100
			cmp.E1RMDeltaKg = &d
		}
		if pV, ok := prevVol[id]; ok {
			pv := math.Round(pV*100) / 100
			cmp.PreviousVolumeKg = &pv
		}
		out = append(out, cmp)
	}
	return out
}

func workoutToCompletedRow(w *workout.Workout) completedWorkoutRow {
	r := completedWorkoutRow{
		ID:              w.ID,
		TotalVolumeKg:   w.TotalVolumeKg,
		DurationSeconds: w.DurationSeconds,
		RoutineID:       w.RoutineID,
		Name:            w.Name,
	}
	if w.Stats != nil {
		r.Stats = w.Stats
	}
	if w.CompletedAt != nil {
		r.CompletedAt = *w.CompletedAt
	}
	return r
}

func toRecoveryLites(checkins []recovery.Checkin) []RecoveryCheckinLite {
	out := make([]RecoveryCheckinLite, 0, len(checkins))
	for _, c := range checkins {
		out = append(out, RecoveryCheckinLite{
			CheckinDate:     c.CheckinDate.UTC().Format("2006-01-02"),
			SleepHours:      c.SleepHours,
			EnergyReadiness: c.EnergyReadiness,
			CaloriesKcal:    c.CaloriesKcal,
			ProteinG:        c.ProteinG,
		})
	}
	return out
}

// CoachContext returns AI-friendly bundle for coach chat.
func (s *Service) CoachContext(ctx context.Context, userID string) (*CoachContextResponse, error) {
	now := time.Now().UTC()
	from7 := now.AddDate(0, 0, -7).Truncate(24 * time.Hour)
	checkins, err := s.recovery.ListByDateRange(ctx, userID, from7, now.Truncate(24*time.Hour))
	if err != nil {
		return nil, err
	}
	prof, err := s.profile.GetByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}
	wrows, err := s.repo.ListCompletedWorkoutsRecent(ctx, userID, coachContextRecentWorkouts)
	if err != nil {
		return nil, err
	}
	allSets := make([][]workout.SetOut, 0, len(wrows))
	for _, row := range wrows {
		sets, err := s.workoutRepo.ListSetsForWorkout(ctx, row.ID)
		if err != nil {
			return nil, err
		}
		allSets = append(allSets, sets)
	}
	recentCoach := buildCoachRecentWorkouts(wrows, allSets)

	routines, err := s.routineRepo.ListRoutinesByUser(ctx, userID)
	if err != nil {
		return nil, err
	}
	routines = capRoutines(routines, coachContextRoutineLimit)
	for i := range routines {
		ex, err := s.routineRepo.ListRoutineExercises(ctx, routines[i].ID)
		if err != nil {
			return nil, err
		}
		routines[i].Exercises = ex
	}

	progRows, err := s.repo.ListRecentCompletedWorkoutSetsForProgression(ctx, userID, exerciseListWindowWorkouts)
	if err != nil {
		return nil, err
	}
	life, err := s.repo.ListLifetimeBestSetPerExercise(ctx, userID)
	if err != nil {
		return nil, err
	}
	lifetime := make(map[string]LifetimeBestSet, len(life))
	for _, lb := range life {
		lifetime[lb.ExerciseID] = lb
	}
	progression := topExerciseProgressionItems(progRows, lifetime, coachContextProgressionTop)

	insights, err := s.insightRepo.ListInsightsForUser(ctx, userID, coachContextAIInsightsLimit)
	if err != nil {
		return nil, err
	}
	actions, err := s.repo.ListPendingAIActions(ctx, userID, coachContextPendingActLimit)
	if err != nil {
		return nil, err
	}

	return &CoachContextResponse{
		Profile:             coachProfileViewFrom(prof),
		StrengthEloSummary:  buildCoachStrengthEloSummary(prof),
		Sharpness:           sharpnessFromCheckins(checkins, prof),
		Recovery:            buildCoachRecoveryContext(checkins),
		RecentWorkouts:      recentCoach,
		ActiveRoutines:      buildCoachRoutines(routines),
		ExerciseProgression: progression,
		RecentAIInsights:    insights,
		PendingAIActions:    actions,
	}, nil
}
