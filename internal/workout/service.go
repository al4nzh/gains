package workout

import (
	"context"
	"encoding/json"
	"math"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"gainsai/internal/exercise"
	"gainsai/internal/profile"
	"gainsai/internal/strength"
)

type Service struct {
	pool    *pgxpool.Pool
	repo    *Repository
	profile *profile.Repository
	exercise *exercise.Repository
}

func NewService(pool *pgxpool.Pool, repo *Repository, prof *profile.Repository, ex *exercise.Repository) *Service {
	return &Service{pool: pool, repo: repo, profile: prof, exercise: ex}
}

func currentElo(p *profile.Profile) int {
	if p != nil && p.StrengthElo != nil {
		return *p.StrengthElo
	}
	return 1000
}

func bodyweightKg(p *profile.Profile) (float64, bool) {
	if p == nil || p.WeightKg == nil || *p.WeightKg <= 0 {
		return 0, false
	}
	return *p.WeightKg, true
}

func (s *Service) StartWorkout(ctx context.Context, userID string, routineID *string, name *string) (*Workout, error) {
	if routineID != nil && strings.TrimSpace(*routineID) == "" {
		routineID = nil
	}
	if routineID != nil {
		ok, err := s.repo.RoutineOwnedBy(ctx, userID, *routineID)
		if err != nil {
			return nil, err
		}
		if !ok {
			return nil, ErrRoutineNotYours
		}
	}
	return s.repo.CreateWorkout(ctx, userID, routineID, name)
}

func (s *Service) GetWorkout(ctx context.Context, userID, workoutID string) (*Workout, error) {
	w, err := s.repo.GetWorkoutForUser(ctx, userID, workoutID)
	if err != nil {
		return nil, err
	}
	sets, err := s.repo.ListSetsForWorkout(ctx, workoutID)
	if err != nil {
		return nil, err
	}
	if sets == nil {
		sets = []SetOut{}
	}
	w.Sets = sets
	return w, nil
}

func (s *Service) ListWorkouts(ctx context.Context, userID string, limit int) ([]Workout, error) {
	return s.repo.ListWorkoutsByUser(ctx, userID, limit)
}

type AddSetInput struct {
	ExerciseID string
	SetNumber  *int
	Reps       *int
	WeightKg   *float64
	RPE        *float64
	IsFailure  bool
	Notes      *string
}

func (s *Service) AddSet(ctx context.Context, userID, workoutID string, in AddSetInput) (*SetOut, error) {
	w, err := s.repo.GetWorkoutForUser(ctx, userID, workoutID)
	if err != nil {
		return nil, err
	}
	if w.IsComplete() {
		return nil, ErrAlreadyFinished
	}
	ok, err := s.repo.ExerciseExists(ctx, in.ExerciseID)
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, ErrExerciseNotFound
	}
	if err := validateSetPayload(in.Reps, in.WeightKg); err != nil {
		return nil, err
	}
	sn := 0
	if in.SetNumber != nil && *in.SetNumber > 0 {
		sn = *in.SetNumber
	} else {
		sn, err = s.repo.NextSetNumber(ctx, workoutID, in.ExerciseID)
		if err != nil {
			return nil, err
		}
	}
	return s.repo.InsertSet(ctx, workoutID, in.ExerciseID, sn, in.Reps, in.WeightKg, in.RPE, in.IsFailure, in.Notes)
}

type UpdateSetInput struct {
	Reps       *int
	WeightKg   *float64
	RPE        *float64
	IsFailure  *bool
	Notes      *string
}

func (s *Service) UpdateSet(ctx context.Context, userID, workoutID, setID string, in UpdateSetInput) (*SetOut, error) {
	w, err := s.repo.GetWorkoutForUser(ctx, userID, workoutID)
	if err != nil {
		return nil, err
	}
	if w.IsComplete() {
		return nil, ErrAlreadyFinished
	}
	cur, err := s.repo.GetSetForWorkout(ctx, workoutID, setID)
	if err != nil {
		return nil, err
	}
	if in.Reps != nil {
		cur.Reps = in.Reps
	}
	if in.WeightKg != nil {
		cur.WeightKg = in.WeightKg
	}
	if in.RPE != nil {
		cur.RPE = in.RPE
	}
	if in.IsFailure != nil {
		cur.IsFailure = *in.IsFailure
	}
	if in.Notes != nil {
		cur.Notes = in.Notes
	}
	if err := validateSetPayload(cur.Reps, cur.WeightKg); err != nil {
		return nil, err
	}
	return s.repo.UpdateSetFull(ctx, workoutID, setID, *cur)
}

func validateSetPayload(reps *int, weight *float64) error {
	if reps == nil || weight == nil {
		return ErrInvalidSetPayload
	}
	if *reps <= 0 || *weight <= 0 {
		return ErrInvalidSetPayload
	}
	return nil
}

func (s *Service) DeleteSet(ctx context.Context, userID, workoutID, setID string) error {
	w, err := s.repo.GetWorkoutForUser(ctx, userID, workoutID)
	if err != nil {
		return err
	}
	if w.IsComplete() {
		return ErrAlreadyFinished
	}
	return s.repo.DeleteSet(ctx, workoutID, setID)
}

type FinishInput struct {
	Notes *string
}

func (s *Service) FinishWorkout(ctx context.Context, userID, workoutID string, in FinishInput) (*FinishStats, error) {
	w, err := s.repo.GetWorkoutForUser(ctx, userID, workoutID)
	if err != nil {
		return nil, err
	}
	if w.IsComplete() {
		return nil, ErrAlreadyFinished
	}
	sets, err := s.repo.ListSetsRaw(ctx, workoutID)
	if err != nil {
		return nil, err
	}
	completedAt := time.Now().UTC()
	dur := int(math.Max(1, completedAt.Sub(w.StartedAt).Seconds()))
	volume := w.VolumeFromSets(sets)

	bestThis := BestE1RMPerExerciseFromSets(sets)
	hist, err := s.repo.HistoricalMaxE1RMPerExercise(ctx, userID, workoutID, strength.Estimate1RMBrzycki)
	if err != nil {
		return nil, err
	}

	exIDs := make([]string, 0, len(bestThis))
	for id := range bestThis {
		exIDs = append(exIDs, id)
	}
	names, err := s.exercise.GetNamesByIDs(ctx, exIDs)
	if err != nil {
		return nil, err
	}

	e1stats := make([]E1RMExerciseStat, 0, len(bestThis))
	for exID, e1 := range bestThis {
		e1stats = append(e1stats, E1RMExerciseStat{
			ExerciseID:   exID,
			ExerciseName: names[exID],
			BestE1RMKg:   math.Round(e1*100) / 100,
		})
	}

	prs := make([]PRStat, 0)
	for exID, curBest := range bestThis {
		prev := hist[exID]
		if curBest > prev+0.01 {
			prs = append(prs, PRStat{
				ExerciseID:         exID,
				ExerciseName:       names[exID],
				PreviousBestE1RMKg: math.Round(prev*100) / 100,
				NewBestE1RMKg:      math.Round(curBest*100) / 100,
			})
		}
	}

	prof, err := s.profile.GetByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}

	stats := FinishStats{
		TotalVolumeKg:   math.Round(volume*100) / 100,
		DurationSeconds: dur,
		SetCount:        len(sets),
		ExerciseCount:   len(bestThis),
		E1RMByExercise:  e1stats,
		PRs:             prs,
	}

	bw, hasBW := bodyweightKg(prof)
	eloBefore := currentElo(prof)
	var eloStat FinishEloStat

	if hasBW && len(bestThis) > 0 {
		S, benchCount := strength.BenchmarkSessionScoreBW(bw, bestThis, names, 6.0)
		if benchCount < 2 {
			goto skipElo
		}
		delta := strength.EloDeltaFromSession(eloBefore, S)
		after := strength.ClampElo(eloBefore + delta)
		rank := strength.RankLabel(after)

		meta, _ := json.Marshal(map[string]any{
			"volume":     stats.TotalVolumeKg,
			"pr_count":   len(prs),
			"session_bw": S,
		})

		tx, err := s.pool.Begin(ctx)
		if err != nil {
			return nil, err
		}
		if err := s.repo.FinishWorkoutTx(ctx, tx, workoutID, completedAt, in.Notes, volume, dur, stats); err != nil {
			_ = tx.Rollback(ctx)
			return nil, err
		}
		if err := s.repo.InsertStrengthEloHistoryTx(ctx, tx, userID, workoutID, eloBefore, after, after-eloBefore, &bw, S, meta); err != nil {
			_ = tx.Rollback(ctx)
			return nil, err
		}
		sum30, err := s.repo.SumEloDelta30dTx(ctx, tx, userID)
		if err != nil {
			_ = tx.Rollback(ctx)
			return nil, err
		}
		if err := s.profile.UpsertStrengthEloTx(ctx, tx, userID, after, rank, sum30); err != nil {
			_ = tx.Rollback(ctx)
			return nil, err
		}
		if err := tx.Commit(ctx); err != nil {
			return nil, err
		}

		eloStat = FinishEloStat{
			BeforeElo:      eloBefore,
			AfterElo:       after,
			Delta:          after - eloBefore,
			Change30d:      sum30,
			BodyweightKg:   math.Round(bw*100) / 100,
			SessionScoreBW: math.Round(S*1000) / 1000,
		}
		stats.StrengthElo = &eloStat
		return &stats, nil
	}

skipElo:
	// No Elo update path (missing bodyweight or no countable lifts for e1RM)
	sum30skip, _ := s.repo.SumEloDelta30d(ctx, userID)
	stats.StrengthElo = &FinishEloStat{
		Skipped:        true,
		BeforeElo:      eloBefore,
		AfterElo:       eloBefore,
		Delta:          0,
		Change30d:      sum30skip,
		BodyweightKg:   bw,
		SessionScoreBW: 0,
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	if err := s.repo.FinishWorkoutTx(ctx, tx, workoutID, completedAt, in.Notes, volume, dur, stats); err != nil {
		_ = tx.Rollback(ctx)
		return nil, err
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return &stats, nil
}
