package gymarchetype

import (
	"math"
	"sort"
	"strings"
	"time"

	"gainsai/internal/strength"
)

const (
	MinWorkouts       = 3
	SecondaryMinRatio = 0.82
)

// ID is a stable slug for client display and sharing.
type ID string

const (
	BackDayDemon      ID = "back_day_demon"
	BenchMerchant     ID = "bench_merchant"
	PRGoblin          ID = "pr_goblin"
	LegDayFugitive    ID = "leg_day_fugitive"
	Powerbuilder      ID = "powerbuilder"
	AestheticMerchant ID = "aesthetic_merchant"
	ComebackArc       ID = "comeback_arc"
	ConsistencyDemon  ID = "consistency_demon"
)

type meta struct {
	Label   string
	Tagline string
}

var catalog = map[ID]meta{
	BackDayDemon:      {Label: "Back Day Demon", Tagline: "Every day is pull day if you believe hard enough."},
	BenchMerchant:     {Label: "Bench Merchant", Tagline: "The barbell bench is your personality trait."},
	PRGoblin:          {Label: "PR Goblin", Tagline: "You smell a new max from three racks away."},
	LegDayFugitive:    {Label: "Leg Day Fugitive", Tagline: "Legs are optional. Allegedly."},
	Powerbuilder:      {Label: "Powerbuilder", Tagline: "Heavy compounds, then more reps. Both."},
	AestheticMerchant: {Label: "Aesthetic Merchant", Tagline: "Mirror muscles are a legitimate asset class."},
	ComebackArc:       {Label: "Comeback Arc", Tagline: "You took a break. Now you're back on the plot."},
	ConsistencyDemon:  {Label: "Consistency Demon", Tagline: "You just keep showing up. Unhinged."},
}

// Response is returned on GET /profile (computed, not stored).
type Response struct {
	Unlocked          bool   `json:"unlocked"`
	WorkoutsCompleted int    `json:"workouts_completed"`
	WorkoutsRequired  int    `json:"workouts_required"`
	PrimaryArchetype  *ID    `json:"primary_archetype,omitempty"`
	PrimaryLabel      string `json:"primary_label,omitempty"`
	PrimaryTagline    string `json:"primary_tagline,omitempty"`
	SecondaryTrait    *ID    `json:"secondary_trait,omitempty"`
	SecondaryLabel    string `json:"secondary_label,omitempty"`
}

// Workout is one completed session used for archetype scoring.
type Workout struct {
	ID            string
	CompletedAt   time.Time
	TotalVolumeKg float64
	PRCount       int
	Name          string
	SessionCat    SessionCategory
}

// Set is one logged set with catalog metadata.
type Set struct {
	WorkoutID    string
	CompletedAt  time.Time
	ExerciseName string
	MuscleGroup  string
	Reps         int
	WeightKg     float64
	VolumeKg     float64
}

// Profile is the subset of profile fields that influence archetype scoring.
type Profile struct {
	FitnessGoal         *string
	TrainingExperience  *string
	TrainingDaysPerWeek *int
}

// Calculate scores archetypes from profile + workout history (pure, testable).
func Calculate(prof Profile, workouts []Workout, sets []Set, totalCompleted int) Response {
	required := MinWorkouts
	out := Response{
		Unlocked:          false,
		WorkoutsCompleted: totalCompleted,
		WorkoutsRequired:  required,
	}
	if totalCompleted < required || len(workouts) == 0 {
		return out
	}

	sig := buildSignals(prof, workouts, sets)
	scores := scoreArchetypes(sig)
	ranked := rankScores(scores)
	if len(ranked) == 0 || ranked[0].score <= 0 {
		return out
	}

	out.Unlocked = true
	top := ranked[0]
	out.PrimaryArchetype = &top.id
	if m, ok := catalog[top.id]; ok {
		out.PrimaryLabel = m.Label
		out.PrimaryTagline = m.Tagline
	}

	if len(ranked) > 1 {
		second := ranked[1]
		if top.score > 0 && second.score/top.score >= SecondaryMinRatio {
			out.SecondaryTrait = &second.id
			if m, ok := catalog[second.id]; ok {
				out.SecondaryLabel = m.Label
			}
		}
	}
	return out
}

type signals struct {
	backShare            float64
	chestShare           float64
	legsShare            float64
	armsShare            float64
	shouldersShare       float64
	aestheticShare       float64
	pullSessionRatio     float64
	pushSessionRatio     float64
	legSessionRatio      float64
	benchSetRatio        float64
	benchmarkVolShare    float64
	isolationVolShare    float64
	lowRepCompoundRatio  float64
	highRepCompoundRatio float64
	avgPRsPerWorkout     float64
	workoutsWithPRRatio  float64
	avgWorkoutsPerWeek   float64
	streakDays           int
	comebackScore        float64
	targetDaysPerWeek    float64
}

type scored struct {
	id    ID
	score float64
}

func buildSignals(prof Profile, workouts []Workout, sets []Set) signals {
	sig := signals{targetDaysPerWeek: targetDaysFromProfile(prof)}

	var volByMuscle map[string]float64
	var totalVol float64
	if len(sets) > 0 {
		volByMuscle, totalVol = volumeByMuscleFromSets(sets)
	} else {
		volByMuscle = map[string]float64{}
		for _, w := range workouts {
			totalVol += w.TotalVolumeKg
		}
	}

	if totalVol > 0 {
		sig.backShare = share(volByMuscle["back"], totalVol)
		sig.chestShare = share(volByMuscle["chest"], totalVol)
		sig.legsShare = share(volByMuscle["legs"], totalVol)
		sig.armsShare = share(volByMuscle["arms"], totalVol)
		sig.shouldersShare = share(volByMuscle["shoulders"], totalVol)
		sig.aestheticShare = share(volByMuscle["arms"]+volByMuscle["shoulders"]+volByMuscle["chest"], totalVol)
	}

	var benchSets, benchmarkVol, isolationVol, lowRepCompound, highRepCompound int
	var compoundSets int
	for _, s := range sets {
		if s.VolumeKg <= 0 {
			continue
		}
		name := strings.ToLower(s.ExerciseName)
		if strings.Contains(name, "bench") {
			benchSets++
		}
		if isIsolationExercise(name, s.MuscleGroup) {
			isolationVol += int(s.VolumeKg)
		}
		if _, ok := strength.BenchmarkLiftFromExerciseName(s.ExerciseName); ok {
			benchmarkVol += int(s.VolumeKg)
			compoundSets++
			if s.Reps <= 5 {
				lowRepCompound++
			}
			if s.Reps >= 8 {
				highRepCompound++
			}
		}
	}
	setCount := len(sets)
	if setCount > 0 {
		sig.benchSetRatio = float64(benchSets) / float64(setCount)
		sig.benchmarkVolShare = float64(benchmarkVol) / totalVol
		sig.isolationVolShare = float64(isolationVol) / totalVol
	}
	if compoundSets > 0 {
		sig.lowRepCompoundRatio = float64(lowRepCompound) / float64(compoundSets)
		sig.highRepCompoundRatio = float64(highRepCompound) / float64(compoundSets)
	}

	var pull, push, leg int
	var totalPRs int
	var workoutsWithPR int
	for _, w := range workouts {
		switch w.SessionCat {
		case SessionPull:
			pull++
		case SessionPush:
			push++
		case SessionLegs, SessionLower:
			leg++
		}
		totalPRs += w.PRCount
		if w.PRCount > 0 {
			workoutsWithPR++
		}
	}
	n := float64(len(workouts))
	if n > 0 {
		sig.pullSessionRatio = float64(pull) / n
		sig.pushSessionRatio = float64(push) / n
		sig.legSessionRatio = float64(leg) / n
		sig.avgPRsPerWorkout = float64(totalPRs) / n
		sig.workoutsWithPRRatio = float64(workoutsWithPR) / n
	}

	dates := completionDatesFromWorkouts(workouts)
	sig.streakDays = streakFromDistinctDescDates(dates, time.Now().UTC())
	sig.avgWorkoutsPerWeek = avgWorkoutsPerWeek(workouts)
	sig.comebackScore = comebackScoreFromWorkouts(workouts)

	return sig
}

func scoreArchetypes(sig signals) map[ID]float64 {
	return map[ID]float64{
		BackDayDemon:      scoreBackDayDemon(sig),
		BenchMerchant:     scoreBenchMerchant(sig),
		PRGoblin:          scorePRGoblin(sig),
		LegDayFugitive:    scoreLegDayFugitive(sig),
		Powerbuilder:      scorePowerbuilder(sig),
		AestheticMerchant: scoreAestheticMerchant(sig),
		ComebackArc:       scoreComebackArc(sig),
		ConsistencyDemon:  scoreConsistencyDemon(sig),
	}
}

func scoreBackDayDemon(sig signals) float64 {
	return clamp01((sig.backShare-0.14)/0.18)*45 +
		clamp01(sig.pullSessionRatio/0.45)*35 +
		clamp01((sig.backShare-sig.chestShare+0.05)/0.15)*20
}

func scoreBenchMerchant(sig signals) float64 {
	return clamp01((sig.chestShare-0.12)/0.18)*40 +
		clamp01(sig.benchSetRatio/0.12)*35 +
		clamp01(sig.pushSessionRatio/0.45)*25
}

func scorePRGoblin(sig signals) float64 {
	return clamp01(sig.avgPRsPerWorkout/1.2)*50 +
		clamp01(sig.workoutsWithPRRatio/0.65)*35 +
		clamp01((sig.avgPRsPerWorkout-0.3)/0.9)*15
}

func scoreLegDayFugitive(sig signals) float64 {
	lowLegs := clamp01((0.16 - sig.legsShare) / 0.14)
	if sig.legsShare < 0.03 {
		lowLegs = 1
	}
	fewLegSessions := clamp01((0.22 - sig.legSessionRatio) / 0.22)
	if sig.legSessionRatio < 0.05 {
		fewLegSessions = 1
	}
	upperBias := clamp01((sig.chestShare+sig.backShare+sig.armsShare+sig.shouldersShare-0.55) / 0.35)
	return lowLegs*45 + fewLegSessions*35 + upperBias*20
}

func scorePowerbuilder(sig signals) float64 {
	compound := clamp01(sig.benchmarkVolShare / 0.45)
	repSpread := clamp01(math.Min(sig.lowRepCompoundRatio, sig.highRepCompoundRatio) / 0.35)
	bigThree := clamp01(sig.benchmarkVolShare / 0.35)
	return compound*40 + repSpread*35 + bigThree*25
}

func scoreAestheticMerchant(sig signals) float64 {
	return clamp01((sig.aestheticShare-0.38)/0.28)*45 +
		clamp01(sig.isolationVolShare/0.35)*35 +
		clamp01((sig.armsShare+sig.shouldersShare-0.18)/0.22)*20
}

func scoreComebackArc(sig signals) float64 {
	return clamp01(sig.comebackScore) * 100
}

func scoreConsistencyDemon(sig signals) float64 {
	vsTarget := 0.0
	if sig.targetDaysPerWeek > 0 {
		vsTarget = clamp01(sig.avgWorkoutsPerWeek / sig.targetDaysPerWeek)
	} else {
		vsTarget = clamp01(sig.avgWorkoutsPerWeek / 4.0)
	}
	streak := clamp01(float64(sig.streakDays) / 14.0)
	frequency := clamp01((sig.avgWorkoutsPerWeek - 2.0) / 3.0)
	return vsTarget*40 + streak*35 + frequency*25
}

func rankScores(scores map[ID]float64) []scored {
	out := make([]scored, 0, len(scores))
	for id, score := range scores {
		out = append(out, scored{id: id, score: score})
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].score == out[j].score {
			return out[i].id < out[j].id
		}
		return out[i].score > out[j].score
	})
	return out
}

func volumeByMuscleFromSets(sets []Set) (map[string]float64, float64) {
	out := map[string]float64{}
	var total float64
	for _, s := range sets {
		if s.VolumeKg <= 0 {
			continue
		}
		mg := strings.ToLower(strings.TrimSpace(s.MuscleGroup))
		if mg == "" {
			mg = "unknown"
		}
		out[mg] += s.VolumeKg
		total += s.VolumeKg
	}
	return out, total
}

func share(part, total float64) float64 {
	if total <= 0 {
		return 0
	}
	return part / total
}

func clamp01(v float64) float64 {
	if v < 0 {
		return 0
	}
	if v > 1 {
		return 1
	}
	return v
}

func targetDaysFromProfile(prof Profile) float64 {
	if prof.TrainingDaysPerWeek != nil && *prof.TrainingDaysPerWeek > 0 {
		d := float64(*prof.TrainingDaysPerWeek)
		if d >= 5 {
			return 5
		}
		return d
	}
	return 3
}

func isIsolationExercise(name, muscleGroup string) bool {
	mg := strings.ToLower(strings.TrimSpace(muscleGroup))
	if mg == "arms" {
		return true
	}
	isolationKeywords := []string{
		"fly", "curl", "pushdown", "extension", "raise", "kickback",
		"lateral", "face pull", "shrug", "pullover",
	}
	for _, kw := range isolationKeywords {
		if strings.Contains(name, kw) {
			return true
		}
	}
	return false
}

func completionDatesFromWorkouts(workouts []Workout) []time.Time {
	seen := map[string]struct{}{}
	var dates []time.Time
	for _, w := range workouts {
		d := w.CompletedAt.UTC().Truncate(24 * time.Hour)
		key := d.Format("2006-01-02")
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		dates = append(dates, d)
	}
	sort.Slice(dates, func(i, j int) bool { return dates[i].After(dates[j]) })
	return dates
}

func avgWorkoutsPerWeek(workouts []Workout) float64 {
	if len(workouts) < 2 {
		return float64(len(workouts))
	}
	oldest := workouts[0].CompletedAt
	newest := workouts[0].CompletedAt
	for _, w := range workouts {
		if w.CompletedAt.Before(oldest) {
			oldest = w.CompletedAt
		}
		if w.CompletedAt.After(newest) {
			newest = w.CompletedAt
		}
	}
	spanDays := newest.Sub(oldest).Hours() / 24
	if spanDays < 7 {
		spanDays = 7
	}
	weeks := spanDays / 7
	if weeks < 1 {
		weeks = 1
	}
	return float64(len(workouts)) / weeks
}

func comebackScoreFromWorkouts(workouts []Workout) float64 {
	if len(workouts) < 3 {
		return 0
	}
	sorted := append([]Workout(nil), workouts...)
	sort.Slice(sorted, func(i, j int) bool {
		return sorted[i].CompletedAt.Before(sorted[j].CompletedAt)
	})

	now := time.Now().UTC()
	recentCutoff := now.AddDate(0, 0, -21)
	recentCount := 0
	for _, w := range sorted {
		if w.CompletedAt.After(recentCutoff) {
			recentCount++
		}
	}
	if recentCount < 3 {
		return 0
	}

	maxGapDays := 0.0
	for i := 1; i < len(sorted); i++ {
		gap := sorted[i].CompletedAt.Sub(sorted[i-1].CompletedAt).Hours() / 24
		if gap > maxGapDays {
			maxGapDays = gap
		}
	}
	if maxGapDays < 14 {
		return 0
	}

	gapScore := clamp01((maxGapDays - 14) / 28)
	momentum := clamp01(float64(recentCount) / 6)
	return gapScore*0.55 + momentum*0.45
}

func streakFromDistinctDescDates(dates []time.Time, now time.Time) int {
	if len(dates) == 0 {
		return 0
	}
	today := now.UTC().Truncate(24 * time.Hour)
	yesterday := today.AddDate(0, 0, -1)
	latest := dates[0].UTC().Truncate(24 * time.Hour)
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
