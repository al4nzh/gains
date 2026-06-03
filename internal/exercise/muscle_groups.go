package exercise

import "strings"

// CatalogMuscleGroups are allowed muscle_group values on system catalog exercises.
var CatalogMuscleGroups = []string{
	"chest",
	"back",
	"legs",
	"shoulders",
	"arms",
	"core",
	"full_body",
}

func normalizeCatalogMuscleGroup(raw string) (string, bool) {
	g := strings.TrimSpace(strings.ToLower(raw))
	if g == "" {
		return "", true
	}
	for _, allowed := range CatalogMuscleGroups {
		if g == allowed {
			return g, true
		}
	}
	return "", false
}
