package ai

import "testing"

func TestExerciseNotInLibraryClarification(t *testing.T) {
	c := exerciseNotInLibraryClarification("Incline Dumbbell Press")
	if c == nil || !c.Required {
		t.Fatal("expected required clarification")
	}
	if c.Message == "" {
		t.Fatal("expected message")
	}
	if len(c.PossibleMatches) != 0 {
		t.Fatal("unknown exercise should not suggest fuzzy matches")
	}
}

func TestExerciseNotInLibraryClarificationEmptyName(t *testing.T) {
	c := exerciseNotInLibraryClarification("")
	if c == nil || !c.Required {
		t.Fatal("expected required clarification")
	}
}
