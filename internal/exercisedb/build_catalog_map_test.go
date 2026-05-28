package exercisedb

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"
)

// TestBuildCatalogMap prints catalogGifIDs entries from a full index download.
// Run: VERIFY_EXERCISEDB=1 go test ./internal/exercisedb -run TestBuildCatalogMap -v
func TestBuildCatalogMap(t *testing.T) {
	if os.Getenv("VERIFY_EXERCISEDB") != "1" {
		t.Skip()
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()
	all, err := NewClient("").ListAll(ctx)
	if err != nil {
		t.Fatal(err)
	}
	idx := buildIndex(all)

	for _, ex := range gainsCatalog {
		target := normalizeName(preferredDBName(ex.Name))
		if picked := idx.lookupExact(target); picked != nil {
			fmt.Printf("\t%q: %q,\n", normalizeName(ex.Name), picked.ExerciseID)
			continue
		}
		cands := idx.candidatesContainingAllTokens(target, tokens(ex.Name))
		picked := pickBest(ex.Name, ex.Equipment, cands)
		if picked != nil {
			fmt.Printf("\t%q: %q, // %s\n", normalizeName(ex.Name), picked.ExerciseID, picked.Name)
		} else {
			fmt.Printf("\t// MISS %s target=%q\n", ex.Name, target)
		}
	}
}
