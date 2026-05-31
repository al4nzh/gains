package analytics

import (
	"encoding/json"
	"math"
	"sort"
	"time"

	"gainsai/internal/strength"
	"gainsai/internal/workout"
)

const exerciseListWindowWorkouts = 36

type exHistEntry struct {
	workoutID string
	at        time.Time
	e1        float64
}

type exAgg struct {
	name string
	hist []exHistEntry
}

func aggregateExerciseHistories(rows []ProgressionSetRow) map[string]*exAgg {
	m := map[string]*exAgg{}
	applyWorkout := func(wid string, at time.Time, sets []workout.Set, names map[string]string) {
		best := workout.BestE1RMPerExerciseFromSets(sets)
		for exID, e1 := range best {
			if e1 <= 0 {
				continue
			}
			ent := exHistEntry{workoutID: wid, at: at, e1: e1}
			a, ok := m[exID]
			n := names[exID]
			if !ok {
				m[exID] = &exAgg{name: n, hist: []exHistEntry{ent}}
				continue
			}
			a.hist = append(a.hist, ent)
			if n != "" {
				a.name = n
			}
		}
	}

	var curW string
	var curAt time.Time
	setBuf := make([]workout.Set, 0, 64)
	names := make(map[string]string)

	for _, row := range rows {
		if curW != "" && row.WorkoutID != curW {
			applyWorkout(curW, curAt, setBuf, names)
			setBuf = setBuf[:0]
			names = make(map[string]string)
			curW = ""
		}
		if curW == "" {
			curW = row.WorkoutID
			curAt = row.CompletedAt
		}
		setBuf = append(setBuf, workout.Set{
			ExerciseID: row.ExerciseID,
			Reps:       row.Reps,
			WeightKg:   row.WeightKg,
		})
		if row.ExerciseName != "" {
			names[row.ExerciseID] = row.ExerciseName
		}
	}
	if curW != "" {
		applyWorkout(curW, curAt, setBuf, names)
	}
	return m
}

func bestSetLoadForWorkoutExercise(rows []ProgressionSetRow, workoutID, exerciseID string) *SetLoadSummary {
	var bestE float64
	var best *SetLoadSummary
	for _, row := range rows {
		if row.WorkoutID != workoutID || row.ExerciseID != exerciseID {
			continue
		}
		if row.Reps == nil || row.WeightKg == nil || *row.Reps <= 0 || *row.WeightKg <= 0 {
			continue
		}
		e := strength.Estimate1RMBrzycki(*row.WeightKg, *row.Reps)
		if e > bestE {
			bestE = e
			r := *row.Reps
			w := *row.WeightKg
			best = &SetLoadSummary{Reps: &r, WeightKg: &w}
		}
	}
	return best
}

const (
	exerciseTrendMaxSessions = 6
	exerciseTrendEpsilonKg   = 0.5
)

func trendLabel(delta float64) string {
	return trendLabelEpsilon(delta, exerciseTrendEpsilonKg)
}

func trendLabelEpsilon(delta, eps float64) string {
	if delta > eps {
		return "up"
	}
	if delta < -eps {
		return "down"
	}
	return "flat"
}

func meanE1RM(vals []float64) float64 {
	if len(vals) == 0 {
		return 0
	}
	var sum float64
	for _, v := range vals {
		sum += v
	}
	return sum / float64(len(vals))
}

// trendFromSessionE1RMs compares average best e1RM in the newer half vs the older half
// within the last up to exerciseTrendMaxSessions (oldest→newest). Smooths session-to-session noise.
// singleLabel is returned when only one session exists (e.g. "single_session" on detail); list uses "" → "flat".
func trendFromSessionE1RMs(series []float64, singleLabel string) string {
	n := len(series)
	if n == 0 {
		return "no_data"
	}
	if n == 1 {
		if singleLabel != "" {
			return singleLabel
		}
		return "flat"
	}
	window := series
	if n > exerciseTrendMaxSessions {
		window = series[n-exerciseTrendMaxSessions:]
	}
	nw := len(window)
	k := nw / 2
	if k < 1 {
		k = 1
	}
	recent := window[nw-k:]
	prior := window[nw-2*k : nw-k]
	var delta float64
	if len(prior) == 0 {
		delta = window[nw-1] - window[nw-2]
	} else {
		delta = meanE1RM(recent) - meanE1RM(prior)
	}
	return trendLabelEpsilon(delta, exerciseTrendEpsilonKg)
}

func streakFromDistinctDescDates(dates []time.Time, now time.Time) int {
	if len(dates) == 0 {
		return 0
	}
	today := now.UTC().Truncate(24 * time.Hour)
	yesterday := today.AddDate(0, 0, -1)
	latest := dates[0].UTC().Truncate(24 * time.Hour)
	// Streak is only active if the most recent workout was today or yesterday.
	if !latest.Equal(today) && !latest.Equal(yesterday) {
		return 0
	}
	streak := 1
	prev := latest
	for i := 1; i < len(dates); i++ {
		d := dates[i].UTC().Truncate(24 * time.Hour)
		exp := prev.AddDate(0, 0, -1)
		if d.Equal(exp) {
			streak++
			prev = d
			continue
		}
		break
	}
	return streak
}

// BuildExerciseListItems builds progress-tab rows from the same window as progression (workout_sets).
// lifetime is user PR per exercise from all completed workouts (see repository lifetime queries).
func BuildExerciseListItems(rows []ProgressionSetRow, lifetime map[string]LifetimeBestSet) []ExerciseListItem {
	m := aggregateExerciseHistories(rows)
	out := make([]ExerciseListItem, 0, len(m))
	for id, a := range m {
		if len(a.hist) == 0 {
			continue
		}
		h := a.hist
		first := h[0].e1
		last := h[len(h)-1].e1
		delta := last - first
		var pct *float64
		if first > 0 {
			p := math.Round((delta/first)*10000) / 100
			pct = &p
		}
		series := make([]float64, len(h))
		for i := range h {
			series[i] = h[i].e1
		}
		trend := trendFromSessionE1RMs(series, "")
		lw := h[len(h)-1].workoutID
		var absE float64
		var absSet *SetLoadSummary
		if lb, ok := lifetime[id]; ok && lb.BestE1RMKg > 0 {
			absE = lb.BestE1RMKg
			rr, ww := lb.Reps, lb.WeightKg
			absSet = &SetLoadSummary{Reps: &rr, WeightKg: &ww}
		}
		out = append(out, ExerciseListItem{
			ExerciseID:         id,
			ExerciseName:       a.name,
			LatestBestSet:      bestSetLoadForWorkoutExercise(rows, lw, id),
			LatestE1RMKg:       math.Round(last*100) / 100,
			AbsoluteBestE1RMKg: math.Round(absE*100) / 100,
			AbsoluteBestSet:    absSet,
			E1RMChangeKg:       math.Round(delta*100) / 100,
			E1RMChangePct:      pct,
			DataPoints:         len(h),
			Trend:              trend,
		})
	}
	sort.Slice(out, func(i, j int) bool {
		ai := math.Abs(out[i].E1RMChangeKg)
		aj := math.Abs(out[j].E1RMChangeKg)
		if ai == aj {
			return out[i].LatestE1RMKg > out[j].LatestE1RMKg
		}
		return ai > aj
	})
	return out
}

// BuildExerciseDetailResponse groups flat set rows by workout for one exercise.
func BuildExerciseDetailResponse(exerciseID string, flat []ExerciseDetailRow) *ExerciseDetailResponse {
	if len(flat) == 0 {
		return &ExerciseDetailResponse{
			ExerciseID: exerciseID, ExerciseName: "", AbsoluteBestE1RMKg: 0,
			History: nil, TrendSummary: "no_data",
		}
	}
	name := flat[0].ExerciseName
	type wk struct {
		id   string
		at   time.Time
		sets []workout.Set
	}
	var cur wk
	var workouts []wk
	flush := func() {
		if cur.id == "" {
			return
		}
		workouts = append(workouts, cur)
	}
	for _, row := range flat {
		if cur.id != "" && row.WorkoutID != cur.id {
			flush()
			cur = wk{}
		}
		if cur.id == "" {
			cur.id = row.WorkoutID
			cur.at = row.CompletedAt
		}
		cur.sets = append(cur.sets, workout.Set{
			ExerciseID: row.ExerciseID,
			Reps:       row.Reps,
			WeightKg:   row.WeightKg,
		})
	}
	flush()

	hist := make([]ExerciseDetailWorkoutEntry, 0, len(workouts))
	for _, w := range workouts {
		bestE := 0.0
		var bestSet ExerciseDetailSetEntry
		var vol float64
		for _, s := range w.sets {
			if s.Reps != nil && s.WeightKg != nil && *s.Reps > 0 && *s.WeightKg > 0 {
				vol += float64(*s.Reps) * *s.WeightKg
				e := strength.Estimate1RMBrzycki(*s.WeightKg, *s.Reps)
				if e > bestE {
					bestE = e
					r := *s.Reps
					wg := *s.WeightKg
					bestSet = ExerciseDetailSetEntry{Reps: &r, WeightKg: &wg}
				}
			}
		}
		var prs []workout.PRStat
		var stats []byte
		for _, row := range flat {
			if row.WorkoutID == w.id {
				stats = row.Stats
				break
			}
		}
		if len(stats) > 0 {
			var fs workout.FinishStats
			if json.Unmarshal(stats, &fs) == nil {
				for _, pr := range fs.PRs {
					if pr.ExerciseID == exerciseID {
						prs = append(prs, pr)
					}
				}
			}
		}
		hist = append(hist, ExerciseDetailWorkoutEntry{
			WorkoutID:   w.id,
			CompletedAt: w.at.UTC().Format(time.RFC3339),
			BestSet:     bestSet,
			BestE1RMKg:  math.Round(bestE*100) / 100,
			VolumeKg:    math.Round(vol*100) / 100,
			PRs:         prs,
		})
	}
	series := make([]float64, len(hist))
	for i := range hist {
		series[i] = hist[i].BestE1RMKg
	}
	trend := trendFromSessionE1RMs(series, "single_session")

	out := &ExerciseDetailResponse{
		ExerciseID:   exerciseID,
		ExerciseName: name,
		History:      hist,
		TrendSummary: trend,
	}
	out.LatestComparison = buildLatestExerciseComparison(hist)
	return out
}

func setLoadSummaryFromDetailSet(e ExerciseDetailSetEntry) *SetLoadSummary {
	if e.Reps == nil || e.WeightKg == nil {
		return nil
	}
	r, w := *e.Reps, *e.WeightKg
	rr, ww := r, w
	return &SetLoadSummary{Reps: &rr, WeightKg: &ww}
}

func buildLatestExerciseComparison(hist []ExerciseDetailWorkoutEntry) *ExerciseDetailLatestComparison {
	if len(hist) < 2 {
		return nil
	}
	prev := hist[len(hist)-2]
	cur := hist[len(hist)-1]
	dE := cur.BestE1RMKg - prev.BestE1RMKg
	dV := cur.VolumeKg - prev.VolumeKg
	out := &ExerciseDetailLatestComparison{
		PreviousCompletedAt: prev.CompletedAt,
		E1RMChangeKg:        math.Round(dE*100) / 100,
		VolumeChangeKg:      math.Round(dV*100) / 100,
		BestSetPrevious:     setLoadSummaryFromDetailSet(prev.BestSet),
		BestSetCurrent:      setLoadSummaryFromDetailSet(cur.BestSet),
	}
	if prev.BestE1RMKg > 0 {
		p := math.Round(dE/prev.BestE1RMKg*10000) / 100
		out.E1RMChangePct = &p
	}
	if prev.VolumeKg > 0 {
		p := math.Round(dV/prev.VolumeKg*10000) / 100
		out.VolumeChangePct = &p
	}
	return out
}

func applyLifetimeBestToDetail(out *ExerciseDetailResponse, lb *LifetimeBestSet) {
	if out == nil || lb == nil || lb.BestE1RMKg <= 0 {
		return
	}
	if out.ExerciseName == "" {
		out.ExerciseName = lb.ExerciseName
	}
	out.AbsoluteBestE1RMKg = math.Round(lb.BestE1RMKg*100) / 100
	r, w := lb.Reps, lb.WeightKg
	out.AbsoluteBestSet = &ExerciseDetailSetEntry{Reps: &r, WeightKg: &w}
	out.AbsoluteBestWorkoutID = lb.WorkoutID
	out.AbsoluteBestCompletedAt = lb.CompletedAt.UTC().Format(time.RFC3339)
}
