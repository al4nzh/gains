package exercisedb

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"
)

// TestProbeCatalog prints best ExerciseDB match per catalog row. Run: VERIFY_EXERCISEDB=1 go test ./internal/exercisedb -run TestProbeCatalog -v
func TestProbeCatalog(t *testing.T) {
	if os.Getenv("VERIFY_EXERCISEDB") != "1" {
		t.Skip()
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()
	c := NewClient("")

	for _, ex := range gainsCatalog {
		time.Sleep(700 * time.Millisecond)
		search := preferredDBName(ex.Name)
		cands, err := c.SearchByName(ctx, search, 50)
		if err != nil {
			t.Logf("ERR %s: %v", ex.Name, err)
			continue
		}
		picked := pickBest(ex.Name, ex.Equipment, cands)
		if picked == nil {
			cands2, _ := c.SearchByName(ctx, normalizeName(ex.Name), 50)
			picked = pickBest(ex.Name, ex.Equipment, cands2)
		}
		if picked == nil {
			fmt.Printf("MISS %s (equip=%s) search=%q\n", ex.Name, ex.Equipment, search)
			continue
		}
		fmt.Printf("OK   %s -> %s | id=%s\n", ex.Name, picked.Name, picked.ExerciseID)
	}
}
