package adaptiverecommendations

import (
	"context"
	"strings"
	"time"

	"gainsai/internal/analytics"
	"gainsai/internal/exercise"
	"gainsai/internal/profile"
	"gainsai/internal/recovery"
	"gainsai/internal/routine"
	"gainsai/internal/workout"
)

type Service struct {
	repo          *Repository
	routineRepo   *routine.Repository
	workoutRepo   *workout.Repository
	recoveryRepo  *recovery.Repository
	profileRepo   *profile.Repository
	analyticsRepo *analytics.Repository
	exerciseRepo  *exercise.Repository
}

func NewService(
	repo *Repository,
	routineRepo *routine.Repository,
	workoutRepo *workout.Repository,
	recoveryRepo *recovery.Repository,
	profileRepo *profile.Repository,
	analyticsRepo *analytics.Repository,
	exerciseRepo *exercise.Repository,
) *Service {
	return &Service{
		repo:          repo,
		routineRepo:   routineRepo,
		workoutRepo:   workoutRepo,
		recoveryRepo:  recoveryRepo,
		profileRepo:   profileRepo,
		analyticsRepo: analyticsRepo,
		exerciseRepo:  exerciseRepo,
	}
}

func (s *Service) ForRoutine(ctx context.Context, userID, routineID string) (*ListResponse, error) {
	if _, err := s.routineRepo.GetRoutineForUser(ctx, userID, routineID); err != nil {
		if err == routine.ErrNotFound {
			return nil, ErrRoutineNotYours
		}
		return nil, err
	}
	exercises, err := s.routineRepo.ListRoutineExercises(ctx, routineID)
	if err != nil {
		return nil, err
	}
	in, summary, err := s.buildEvalInput(ctx, userID, routineID, exercises)
	if err != nil {
		return nil, err
	}
	recs := buildRecommendations(in, "routine")
	return &ListResponse{Recommendations: recs, ContextSummary: summary}, nil
}

func (s *Service) Apply(ctx context.Context, userID, workoutID, recommendationID string) (*ApplyResponse, error) {
	w, err := s.workoutRepo.GetWorkoutForUser(ctx, userID, workoutID)
	if err != nil {
		if err == workout.ErrNotFound {
			return nil, ErrWorkoutNotYours
		}
		return nil, err
	}
	if w.IsComplete() {
		return nil, ErrWorkoutNotActive
	}

	if w.RoutineID == nil {
		return nil, ErrRecommendationUnknown
	}
	if _, err := s.routineRepo.GetRoutineForUser(ctx, userID, *w.RoutineID); err != nil {
		return nil, ErrRoutineNotYours
	}
	exercises, err := s.routineRepo.ListRoutineExercises(ctx, *w.RoutineID)
	if err != nil {
		return nil, err
	}
	in, _, err := s.buildEvalInput(ctx, userID, *w.RoutineID, exercises)
	if err != nil {
		return nil, err
	}
	recs := buildRecommendations(in, "routine")

	var rec *Recommendation
	for i := range recs {
		if recs[i].ID == recommendationID {
			rec = &recs[i]
			break
		}
	}
	if rec == nil {
		return nil, ErrRecommendationUnknown
	}

	change := rec.SuggestedChange
	if change.ReplaceExerciseName != nil && (change.ReplaceExerciseID == nil || *change.ReplaceExerciseID == "") {
		id, _, err := s.exerciseRepo.ResolveCatalogByName(ctx, *change.ReplaceExerciseName, 10)
		if err != nil {
			return nil, err
		}
		if id != "" {
			change.ReplaceExerciseID = &id
		}
	}

	adj := AppliedAdjustment{
		RecommendationID:        rec.ID,
		Type:                    rec.Type,
		TargetExerciseID:        rec.TargetExerciseID,
		TargetRoutineExerciseID: rec.TargetRoutineExerciseID,
		TargetMuscleGroup:       rec.TargetMuscleGroup,
		Change:                  change,
		AppliedAt:               time.Now().UTC().Format(time.RFC3339),
	}

	all, err := s.repo.AppendAppliedAdjustment(ctx, userID, workoutID, adj)
	if err != nil {
		return nil, err
	}
	return &ApplyResponse{
		WorkoutID:           workoutID,
		Applied:             adj,
		AdaptiveAdjustments: all,
	}, nil
}

func (s *Service) buildEvalInput(ctx context.Context, userID, routineID string, exercises []routine.RoutineExerciseOut) (evalInput, *ContextSummary, error) {
	prof, _ := s.profileRepo.GetByUserID(ctx, userID)

	in := evalInput{
		RoutineID:            routineID,
		ExerciseTrends:       map[string]string{},
		ExerciseSessionCount: map[string]int{},
		WeeklyVolByMuscle:    map[string]float64{},
		PriorVolByMuscle:     map[string]float64{},
		ExerciseMeta:         map[string]exerciseMeta{},
	}
	summary := &ContextSummary{}

	if prof != nil && prof.InjuryNotes != nil {
		in.InjuryText = *prof.InjuryNotes
		summary.HasInjuryNotes = strings.TrimSpace(in.InjuryText) != ""
	}

	now := time.Now().UTC()
	from7 := now.AddDate(0, 0, -7)
	checkins, _ := s.recoveryRepo.ListByDateRange(ctx, userID, from7, now)
	if len(checkins) > 0 {
		sh := analytics.SharpnessFromCheckinsForAdaptive(checkins, prof)
		if sh != nil {
			in.SharpnessScore = sh.Score
			in.HasSharpness = true
			summary.SharpnessScore = &sh.Score
		}
		summary.RecoveryCheckinOK = true
	}
	latest, err := s.recoveryRepo.GetLatest(ctx, userID)
	if err == nil && latest != nil {
		in.LatestSleepHours = latest.SleepHours
		in.HasSleep = true
		summary.LatestSleepHours = &latest.SleepHours
		in.LatestEnergy = latest.EnergyReadiness
		in.HasEnergy = true
		summary.LatestEnergy = &latest.EnergyReadiness
		if latest.Notes != nil {
			in.InjuryText = strings.TrimSpace(in.InjuryText + " " + *latest.Notes)
		}
		summary.RecoveryCheckinOK = true
	}

	weekStart := now.AddDate(0, 0, -7)
	priorStart := now.AddDate(0, 0, -14)
	in.WeeklyVolByMuscle, _ = s.repo.VolumeByMuscleForRoutine(ctx, userID, routineID, weekStart, now)
	in.PriorVolByMuscle, _ = s.repo.VolumeByMuscleForRoutine(ctx, userID, routineID, priorStart, weekStart)

	routineExIDs := make(map[string]struct{}, len(exercises))
	for _, ex := range exercises {
		routineExIDs[ex.ExerciseID] = struct{}{}
	}

	rows, err := s.analyticsRepo.ListRecentCompletedWorkoutSetsForProgressionByRoutine(ctx, userID, routineID, 24)
	if err != nil {
		return in, summary, err
	}
	agg := analytics.AggregateExerciseHistoriesForAdaptive(rows)
	for exID, a := range agg {
		if _, inRoutine := routineExIDs[exID]; !inRoutine {
			continue
		}
		in.ExerciseSessionCount[exID] = len(a.Hist)
		in.ExerciseTrends[exID] = a.Trend
	}

	exIDs := make([]string, 0, len(exercises))
	for _, ex := range exercises {
		exIDs = append(exIDs, ex.ExerciseID)
	}
	metaMap, err := s.exerciseRepo.GetMetaByIDs(ctx, uniqueStrings(exIDs))
	if err != nil {
		return in, summary, err
	}
	for id, m := range metaMap {
		in.ExerciseMeta[id] = exerciseMeta{ID: m.ID, Name: m.Name, MuscleGroup: m.MuscleGroup}
	}
	// Catalog ids for swap targets
	for _, name := range []string{"Dumbbell Bench Press", "Dumbbell Shoulder Press", "Cable Fly", "Lat Pulldown"} {
		id, _, _ := s.exerciseRepo.ResolveCatalogByName(ctx, name, 5)
		if id != "" {
			if m, ok := metaMap[id]; ok {
				in.ExerciseMeta[id] = exerciseMeta{ID: m.ID, Name: m.Name, MuscleGroup: m.MuscleGroup}
			} else if m2, err := s.exerciseRepo.GetMetaByIDs(ctx, []string{id}); err == nil {
				if mm, ok := m2[id]; ok {
					in.ExerciseMeta[id] = exerciseMeta{ID: mm.ID, Name: mm.Name, MuscleGroup: mm.MuscleGroup}
				}
			}
		}
	}

	routineRows := make([]routineExerciseEval, 0, len(exercises))
	for _, ex := range exercises {
		mg := ""
		if m, ok := in.ExerciseMeta[ex.ExerciseID]; ok {
			mg = m.MuscleGroup
		}
		routineRows = append(routineRows, routineExerciseEval{
			RoutineExerciseID: ex.ID,
			ExerciseID:        ex.ExerciseID,
			ExerciseName:      ex.ExerciseName,
			MuscleGroup:       mg,
			TargetSets:        ex.TargetSets,
			TargetWeightKg:    ex.TargetWeightKg,
			Position:          ex.Position,
		})
	}
	in.RoutineExercises = classifyRoutineExercises(routineRows)
	return in, summary, nil
}

func uniqueStrings(in []string) []string {
	seen := map[string]struct{}{}
	var out []string
	for _, s := range in {
		if s == "" {
			continue
		}
		if _, ok := seen[s]; ok {
			continue
		}
		seen[s] = struct{}{}
		out = append(out, s)
	}
	return out
}
