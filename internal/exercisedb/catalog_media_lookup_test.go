package exercisedb

import "testing"

func TestCatalogSearchNameForMediaID(t *testing.T) {
	t.Parallel()
	if got := CatalogSearchNameForMediaID("EIeI8Vf"); got != "bench press" {
		t.Fatalf("got %q want bench press", got)
	}
}
