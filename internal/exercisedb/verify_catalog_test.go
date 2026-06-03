package exercisedb

import (
	"context"
	"os"
	"sort"
	"strings"
	"testing"
	"time"
)

// gainsCatalog is the system seed list (name, equipment) from migrations/000004_seed_exercises.up.sql
// plus expansions like migrations/000024_expand_seed_exercises.up.sql.
var gainsCatalog = []struct {
	Name      string
	Equipment string
}{
	{"Bench Press", "barbell"},
	{"Incline Bench Press", "barbell"},
	{"Incline DB Press", "dumbbell"},
	{"Dumbbell Bench Press", "dumbbell"},
	{"Cable Fly", "cable"},
	{"Push Up", "bodyweight"},
	{"Dip", "bodyweight"},
	{"Squat", "barbell"},
	{"Front Squat", "barbell"},
	{"Leg Press", "machine"},
	{"Romanian Deadlift", "barbell"},
	{"Leg Curl", "machine"},
	{"Leg Extension", "machine"},
	{"Walking Lunge", "dumbbell"},
	{"Bulgarian Split Squat", "dumbbell"},
	{"Hip Thrust", "barbell"},
	{"Calf Raise", "machine"},
	{"Deadlift", "barbell"},
	{"Sumo Deadlift", "barbell"},
	{"Pull Up", "bodyweight"},
	{"Chin Up", "bodyweight"},
	{"Lat Pulldown", "machine"},
	{"Barbell Row", "barbell"},
	{"Pendlay Row", "barbell"},
	{"Dumbbell Row", "dumbbell"},
	{"Cable Row", "cable"},
	{"T-Bar Row", "machine"},
	{"Face Pull", "cable"},
	{"OHP", "barbell"},
	{"Dumbbell Shoulder Press", "dumbbell"},
	{"Lateral Raise", "dumbbell"},
	{"Front Raise", "dumbbell"},
	{"Rear Delt Fly", "dumbbell"},
	{"Arnold Press", "dumbbell"},
	{"Curls", "dumbbell"},
	{"Barbell Curl", "barbell"},
	{"Hammer Curl", "dumbbell"},
	{"Preacher Curl", "machine"},
	{"Triceps Pushdown", "cable"},
	{"Skull Crusher", "barbell"},
	{"Overhead Triceps Extension", "dumbbell"},
	{"Close Grip Bench Press", "barbell"},
	{"Plank", "bodyweight"},
	{"Hanging Leg Raise", "bodyweight"},
	{"Cable Crunch", "cable"},
	{"Farmer Carry", "dumbbell"},
	{"Kettlebell Swing", "kettlebell"},

	// Expanded catalog (000024)
	{"Decline Bench Press", "barbell"},
	{"Machine Chest Press", "machine"},
	{"Dumbbell Fly", "dumbbell"},
	{"Straight-Arm Pulldown", "cable"},
	{"Machine Pulldown", "machine"},
	{"Shrug", "dumbbell"},
	{"Hack Squat", "machine"},
	{"Smith Squat", "machine"},
	{"Goblet Squat", "dumbbell"},
	{"Good Morning", "barbell"},
	{"Glute Bridge", "barbell"},
	{"Step Up", "dumbbell"},
	{"Seated Leg Curl", "machine"},
	{"Seated Calf Raise", "machine"},
	{"Standing Calf Raise", "machine"},
	{"Machine Shoulder Press", "machine"},
	{"Cable Lateral Raise", "cable"},
	{"Upright Row", "barbell"},
	{"EZ Bar Curl", "barbell"},
	{"Cable Curl", "cable"},
	{"Incline DB Curl", "dumbbell"},
	{"Rope Triceps Pushdown", "cable"},
	{"Cable Overhead Triceps Extension", "cable"},
	{"Russian Twist", "bodyweight"},
	{"Side Plank", "bodyweight"},
}

// TestVerifyGainsCatalogAgainstExerciseDB hits the live OSS API. Skip with: go test -short
func TestVerifyGainsCatalogAgainstExerciseDB(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping live ExerciseDB verification in -short mode")
	}
	if os.Getenv("VERIFY_EXERCISEDB") != "1" {
		t.Skip("set VERIFY_EXERCISEDB=1 to run live catalog GIF verification")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()

	svc := NewService(NewClient(""), true)
	var missing, weak []string
	seenGIF := make(map[string][]string)

	for _, ex := range gainsCatalog {
		url, err := svc.resolve(ctx, ex.Name, ex.Equipment)
		if err != nil || url == "" {
			missing = append(missing, ex.Name)
			continue
		}
		seenGIF[url] = append(seenGIF[url], ex.Name)
		// Flag suspiciously short token-only matches logged via pick debug - optional
		if strings.Contains(url, "potty") {
			weak = append(weak, ex.Name+" -> "+url)
		}
	}

	for url, names := range seenGIF {
		if len(names) > 1 {
			t.Logf("shared gif (%d exercises): %v -> %s", len(names), names, url)
		}
	}
	if len(weak) > 0 {
		t.Errorf("weak matches: %v", weak)
	}
	if len(missing) > 0 {
		// Optional debug: print candidate suggestions from the full ExerciseDB index.
		if os.Getenv("SUGGEST_EXERCISEDB") == "1" {
			idx, err := svc.index.get(ctx, svc.client)
			if err == nil && idx != nil {
				for _, name := range missing {
					var equip string
					for _, ex := range gainsCatalog {
						if ex.Name == name {
							equip = ex.Equipment
							break
						}
					}
					suggestions := suggestCandidates(idx, name, equip, 8)
					if len(suggestions) > 0 {
						t.Logf("suggest %q (%s): %v", name, equip, suggestions)
					} else {
						t.Logf("suggest %q (%s): (no candidates)", name, equip)
					}
				}
			}
		}
		t.Errorf("no gif for %d catalog exercises: %v", len(missing), missing)
	}
}

func suggestCandidates(idx *index, catalogName, equipment string, limit int) []string {
	target := normalizeName(preferredDBName(catalogName))
	cands := idx.candidatesContainingAllTokens(target, tokens(catalogName))
	if len(cands) == 0 {
		return nil
	}
	type scored struct {
		name  string
		score int
	}
	equipSyns := equipmentTokens[strings.ToLower(strings.TrimSpace(equipment))]
	out := make([]scored, 0, len(cands))
	for i := range cands {
		c := &cands[i]
		if c.GifURL == "" {
			continue
		}
		out = append(out, scored{name: c.Name, score: scoreCandidate(target, tokens(catalogName), equipSyns, c)})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].score > out[j].score })
	if limit <= 0 {
		limit = 8
	}
	if len(out) > limit {
		out = out[:limit]
	}
	uniq := make([]string, 0, len(out))
	seen := map[string]bool{}
	for _, s := range out {
		if !seen[s.name] {
			seen[s.name] = true
			uniq = append(uniq, s.name)
		}
	}
	return uniq
}
