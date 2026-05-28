package exercisedb

import (
	"strings"
	"unicode"
)

// catalogAliasNames maps normalized Gains catalog names to preferred ExerciseDB names.
var catalogAliasNames = map[string]string{
	"bench press":              "barbell bench press",
	"incline bench press":      "barbell incline bench press",
	"incline db press":         "dumbbell incline bench press",
	"dumbbell bench press":     "dumbbell bench press",
	"cable fly":                "cable fly",
	"push up":                  "push-up (male)",
	"dip":                      "chest dip",
	"squat":                    "barbell full squat",
	"front squat":              "barbell front squat",
	"leg press":                "sled 45 leg press",
	"romanian deadlift":        "barbell romanian deadlift",
	"leg curl":                 "lever lying leg curl",
	"leg extension":            "lever leg extension",
	"walking lunge":            "dumbbell walking lunge",
	"bulgarian split squat":    "dumbbell bulgarian split squat",
	"hip thrust":               "barbell hip thrust",
	"calf raise":               "lever standing calf raise",
	"deadlift":                 "barbell deadlift",
	"sumo deadlift":            "barbell sumo deadlift",
	"pull up":                  "pull-up",
	"chin up":                  "chin-up",
	"lat pulldown":             "cable pulldown",
	"barbell row":              "barbell bent over row",
	"pendlay row":              "barbell pendlay row",
	"dumbbell row":             "dumbbell bent over row",
	"cable row":                "cable seated row",
	"t-bar row":                "lever t bar row",
	"face pull":                "cable face pull",
	"row":                      "cable seated row",
	"ohp":                      "barbell standing overhead press",
	"overhead press":           "barbell standing overhead press",
	"dumbbell shoulder press":  "dumbbell shoulder press",
	"lateral raise":            "dumbbell lateral raise",
	"front raise":              "dumbbell front raise",
	"rear delt fly":            "dumbbell rear delt fly",
	"arnold press":             "dumbbell arnold press",
	"curls":                    "dumbbell biceps curl",
	"barbell curl":             "barbell curl",
	"hammer curl":              "dumbbell hammer curl",
	"preacher curl":            "preacher curl",
	"triceps pushdown":         "cable pushdown",
	"skull crusher":            "barbell lying triceps extension",
	"overhead triceps extension": "dumbbell overhead triceps extension",
	"close grip bench press":   "barbell close-grip bench press",
	"plank":                    "front plank",
	"hanging leg raise":        "hanging leg raise",
	"cable crunch":             "cable kneeling crunch",
	"farmer carry":             "farmers walk",
	"kettlebell swing":         "kettlebell swing",
}

var equipmentTokens = map[string][]string{
	"barbell":    {"barbell"},
	"dumbbell":   {"dumbbell"},
	"machine":    {"leverage machine", "smith machine", "sled machine", "lever"},
	"cable":      {"cable"},
	"bodyweight": {"body weight", "bodyweight"},
	"kettlebell": {"kettlebell"},
}

func normalizeName(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	var b strings.Builder
	lastSpace := false
	for _, r := range s {
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			b.WriteRune(r)
			lastSpace = false
			continue
		}
		if !lastSpace && b.Len() > 0 {
			b.WriteByte(' ')
			lastSpace = true
		}
	}
	return strings.TrimSpace(b.String())
}

func tokens(s string) []string {
	s = normalizeName(s)
	if s == "" {
		return nil
	}
	return strings.Fields(s)
}

func preferredDBName(catalogName string) string {
	key := normalizeName(catalogName)
	if alias, ok := catalogAliasNames[key]; ok {
		return alias
	}
	return key
}

func pickBest(catalogName, equipment string, candidates []Exercise) *Exercise {
	if len(candidates) == 0 {
		return nil
	}
	target := normalizeName(preferredDBName(catalogName))
	catalogTokens := tokens(catalogName)
	equipSyns := equipmentTokens[strings.ToLower(strings.TrimSpace(equipment))]

	bestScore := -1
	var best *Exercise
	for i := range candidates {
		c := &candidates[i]
		if c.GifURL == "" {
			continue
		}
		score := scoreCandidate(target, catalogTokens, equipSyns, c)
		if score > bestScore {
			bestScore = score
			best = c
		}
	}
	// Short catalog names ("dip", "row") need a confident match to avoid wrong GIFs.
	minScore := 40
	if len(catalogTokens) <= 2 {
		minScore = 70
	}
	if bestScore < minScore {
		return nil
	}
	return best
}

func scoreCandidate(target string, catalogTokens, equipSyns []string, c *Exercise) int {
	name := normalizeName(c.Name)
	if name == target {
		return 1000
	}
	score := 0
	for _, t := range catalogTokens {
		if t == "" {
			continue
		}
		if strings.Contains(name, t) {
			score += 25
		} else {
			score -= 15
		}
	}
	if target != "" && strings.Contains(name, target) {
		score += 80
	}
	nameToks := tokens(name)
	extra := len(nameToks) - len(catalogTokens)
	if extra > 0 {
		score -= extra * 4
	}
	if len(equipSyns) > 0 {
		eq := strings.ToLower(strings.Join(c.Equipments, " "))
		matched := false
		for _, syn := range equipSyns {
			if strings.Contains(eq, syn) {
				matched = true
				break
			}
		}
		if matched {
			score += 35
		} else if eq != "" {
			score -= 10
		}
	}
	return score
}
