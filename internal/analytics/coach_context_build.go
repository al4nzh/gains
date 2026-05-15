package analytics

import (
	"encoding/json"
	"math"
	"time"

	"gainsai/internal/profile"
	"gainsai/internal/recovery"
	"gainsai/internal/routine"
	"gainsai/internal/strength"
	"gainsai/internal/workout"
)

const (
	coachContextRecentWorkouts  = 5
	coachContextRoutineLimit    = 5
	coachContextProgressionTop  = 8
	coachContextAIInsightsLimit = 15
	coachContextPendingActLimit = 25
)

func buildCoachStrengthEloSummary(p *profile.Profile) *CoachStrengthEloSummary {
	if p == nil {
		return nil
	}
	return &CoachStrengthEloSummary{
		CurrentElo:  p.StrengthElo,
		Rank:        p.StrengthEloRank,
		Change30d:   p.StrengthEloChange30d,
		LastUpdated: p.LastStrengthEloUpdate,
	}
}

func buildCoachRecoveryContext(checkins []recovery.Checkin) CoachRecoveryContext {
	out := CoachRecoveryContext{Averages7d: CoachRecovery7dAverages{}}
	n := len(checkins)
	if n == 0 {
		return out
	}
	last := checkins[n-1]
	out.Latest = &CoachLatestRecoveryCheckin{
		CheckinDate:     last.CheckinDate.UTC().Format("2006-01-02"),
		SleepHours:      last.SleepHours,
		EnergyReadiness: last.EnergyReadiness,
		CaloriesKcal:    last.CaloriesKcal,
		ProteinG:        last.ProteinG,
		Notes:           last.Notes,
	}
	var sumSleep, sumEnergy, sumCal, sumProt float64
	for _, c := range checkins {
		sumSleep += c.SleepHours
		sumEnergy += float64(c.EnergyReadiness)
		sumCal += float64(c.CaloriesKcal)
		sumProt += float64(c.ProteinG)
	}
	fn := float64(n)
	out.Averages7d = CoachRecovery7dAverages{
		DaysWithData:    n,
		SleepHours:      math.Round(sumSleep/fn*100) / 100,
		EnergyReadiness: math.Round(sumEnergy/fn*100) / 100,
		CaloriesKcal:    math.Round(sumCal/fn*100) / 100,
		ProteinG:        math.Round(sumProt/fn*100) / 100,
	}
	return out
}

func buildCoachRecentWorkouts(rows []completedWorkoutRow, allSets [][]workout.SetOut) []CoachRecentWorkout {
	n := len(rows)
	if len(allSets) < n {
		n = len(allSets)
	}
	out := make([]CoachRecentWorkout, 0, n)
	for i := 0; i < n; i++ {
		out = append(out, coachRecentWorkoutFromRow(rows[i], allSets[i]))
	}
	return out
}

func coachRecentWorkoutFromRow(row completedWorkoutRow, sets []workout.SetOut) CoachRecentWorkout {
	vol := 0.0
	if row.TotalVolumeKg != nil {
		vol = *row.TotalVolumeKg
	}
	dur := 0
	if row.DurationSeconds != nil {
		dur = *row.DurationSeconds
	}
	if len(row.Stats) > 0 {
		var fs workout.FinishStats
		if json.Unmarshal(row.Stats, &fs) == nil {
			if vol == 0 {
				vol = fs.TotalVolumeKg
			}
			if dur == 0 {
				dur = fs.DurationSeconds
			}
		}
	}
	return CoachRecentWorkout{
		WorkoutID:        row.ID,
		Name:             row.Name,
		RoutineID:        row.RoutineID,
		CompletedAt:      row.CompletedAt.UTC().Format(time.RFC3339),
		TotalVolumeKg:    math.Round(vol*100) / 100,
		DurationSeconds:  dur,
		StrengthEloDelta: eloDeltaFromStats(row.Stats),
		Exercises:        coachWorkoutExerciseSummaries(sets),
	}
}

func coachWorkoutExerciseSummaries(sets []workout.SetOut) []CoachWorkoutExerciseSummary {
	if len(sets) == 0 {
		return nil
	}
	var order []string
	groups := make(map[string][]workout.SetOut)
	names := make(map[string]string)
	for _, so := range sets {
		id := so.ExerciseID
		if _, ok := groups[id]; !ok {
			order = append(order, id)
		}
		groups[id] = append(groups[id], so)
		if so.ExerciseName != "" {
			names[id] = so.ExerciseName
		}
	}
	out := make([]CoachWorkoutExerciseSummary, 0, len(order))
	for _, exID := range order {
		g := groups[exID]
		nm := names[exID]
		ss := make([]CoachWorkoutSetSummary, 0, len(g))
		var vol float64
		bestE := 0.0
		var bestSet *SetLoadSummary
		for _, so := range g {
			s := so.Set
			ss = append(ss, CoachWorkoutSetSummary{
				SetNumber: s.SetNumber,
				Reps:      s.Reps,
				WeightKg:  s.WeightKg,
				RPE:       s.RPE,
				IsFailure: s.IsFailure,
			})
			if s.Reps != nil && s.WeightKg != nil && *s.Reps > 0 && *s.WeightKg > 0 {
				vol += float64(*s.Reps) * *s.WeightKg
				e := strength.Estimate1RMBrzycki(*s.WeightKg, *s.Reps)
				if e > bestE {
					bestE = e
					rr, ww := *s.Reps, *s.WeightKg
					bestSet = &SetLoadSummary{Reps: &rr, WeightKg: &ww}
				}
			}
		}
		out = append(out, CoachWorkoutExerciseSummary{
			ExerciseID:   exID,
			ExerciseName: nm,
			Sets:         ss,
			BestSet:      bestSet,
			BestE1RMKg:   math.Round(bestE*100) / 100,
			VolumeKg:     math.Round(vol*100) / 100,
		})
	}
	return out
}

func topExerciseProgressionItems(rows []ProgressionSetRow, lifetime map[string]LifetimeBestSet, topN int) []ExerciseListItem {
	all := BuildExerciseListItems(rows, lifetime)
	if topN <= 0 || len(all) <= topN {
		return all
	}
	return all[:topN]
}

func capRoutines(r []routine.Routine, maxN int) []routine.Routine {
	if r == nil {
		return []routine.Routine{}
	}
	if maxN <= 0 || len(r) <= maxN {
		return r
	}
	return r[:maxN]
}
