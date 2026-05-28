package exercisedb

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"
)

func TestCatalogGifIDsValid(t *testing.T) {
	if os.Getenv("VERIFY_EXERCISEDB") != "1" {
		t.Skip()
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()
	c := NewClient("")

	for catalog, id := range catalogGifIDs {
		ex, err := c.GetByID(ctx, id)
		if err != nil {
			t.Errorf("%s id=%s: %v", catalog, id, err)
			continue
		}
		fmt.Printf("%s -> %s (%s)\n", catalog, id, ex.Name)
	}
}
