package analytics

import (
	"encoding/json"
	"math"
	"time"

	"gainsai/internal/ai"
	"gainsai/internal/profile"
	"gainsai/internal/recovery"
	"gainsai/internal/routine"
	"gainsai/internal/user"
	"gainsai/internal/workout"
)

type Service struct {
	repo        *Repository
	recovery    *recovery.Repository
	profile     *profile.Repository
	routineRepo *routine.Repository
	workoutRepo *workout.Repository
	insightRepo *ai.Repository
	users       *user.Repository
}

func NewService(repo *Repository, rec *recovery.Repository, prof *profile.Repository, routineRepo *routine.Repository, workoutRepo *workout.Repository, insightRepo *ai.Repository, users *user.Repository) *Service {
	return &Service{repo: repo, recovery: rec, profile: prof, routineRepo: routineRepo, workoutRepo: workoutRepo, insightRepo: insightRepo, users: users}
}

// sharpnessForHome always returns a SharpnessOverview for GET /home: real score when 7d check-ins
// exist; otherwise a zeroed snapshot with the same target fields as if averages were 0 (no data).
func sharpnessForHome(checkins []recovery.Checkin, prof *profile.Profile) *SharpnessOverview {
	if len(checkins) > 0 {
		return sharpnessFromCheckins(checkins, prof)
	}
	w := 75.0
	var goal, activityLevel *string
	if prof != nil {
		goal = prof.FitnessGoal
		activityLevel = prof.ActivityLevel
		if prof.WeightKg != nil && *prof.WeightKg > 0 {
			w = *prof.WeightKg
		}
	}
	return sharpnessFromAverages(0, 0, 0, 0, 1, w, goal, activityLevel)
}

func sharpnessFromCheckins(checkins []recovery.Checkin, prof *profile.Profile) *SharpnessOverview {
	if len(checkins) == 0 {
		return nil
	}
	var sumSleep, sumEnergy, sumCal, sumProt float64
	for _, c := range checkins {
		sumSleep += c.SleepHours
		sumEnergy += float64(c.EnergyReadiness)
		sumCal += float64(c.CaloriesKcal)
		sumProt += float64(c.ProteinG)
	}
	n := float64(len(checkins))
	avgS := sumSleep / n
	avgE := sumEnergy / n
	avgC := sumCal / n
	avgP := sumProt / n

	w := 75.0
	var goal *string
	var activityLevel *string
	if prof != nil {
		goal = prof.FitnessGoal
		activityLevel = prof.ActivityLevel
		if prof.WeightKg != nil && *prof.WeightKg > 0 {
			w = *prof.WeightKg
		}
	}
	return sharpnessFromAverages(avgS, avgE, avgC, avgP, len(checkins), w, goal, activityLevel)
}

func buildLastWorkoutComparison(latest completedWorkoutRow, prev *completedWorkoutRow) *LastWorkoutComparison {
	if prev == nil {
		return &LastWorkoutComparison{FirstSession: true}
	}
	latestSnap := snapshotFromRow(latest)
	prevSnap := snapshotFromRow(*prev)
	cmp := &LastWorkoutComparison{
		Latest:   &latestSnap,
		Previous: &prevSnap,
	}
	if prevSnap.TotalVolumeKg > 0 {
		p := (latestSnap.TotalVolumeKg - prevSnap.TotalVolumeKg) / prevSnap.TotalVolumeKg * 100
		cmp.VolumeDeltaPct = &p
	}
	if prevSnap.DurationSeconds > 0 {
		p := float64(latestSnap.DurationSeconds-prevSnap.DurationSeconds) / float64(prevSnap.DurationSeconds) * 100
		cmp.DurationDeltaPct = &p
	}
	d := latestSnap.SetCount - prevSnap.SetCount
	cmp.SetCountDelta = &d
	return cmp
}

func snapshotFromRow(r completedWorkoutRow) WorkoutSnapshot {
	vol := 0.0
	if r.TotalVolumeKg != nil {
		vol = *r.TotalVolumeKg
	}
	dur := 0
	if r.DurationSeconds != nil {
		dur = *r.DurationSeconds
	}
	sets := 0
	var fs workout.FinishStats
	if len(r.Stats) > 0 && json.Unmarshal(r.Stats, &fs) == nil {
		sets = fs.SetCount
		if vol == 0 {
			vol = fs.TotalVolumeKg
		}
		if dur == 0 {
			dur = fs.DurationSeconds
		}
	}
	return WorkoutSnapshot{
		WorkoutID:       r.ID,
		CompletedAt:     r.CompletedAt.UTC().Format(time.RFC3339),
		TotalVolumeKg:   math.Round(vol*100) / 100,
		DurationSeconds: dur,
		SetCount:        sets,
	}
}
