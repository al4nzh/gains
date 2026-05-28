package exercisedb

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestStaticCatalogGIFsResolve(t *testing.T) {
	for _, ex := range gainsCatalog {
		key := normalizeName(ex.Name)
		url, ok := staticCatalogGIFURL(key)
		if !ok || url == "" {
			t.Errorf("%s: missing static gif mapping", ex.Name)
		}
	}
}

func TestStaticCatalogGIFURL_HTTP200(t *testing.T) {
	if testing.Short() {
		t.Skip()
	}
	client := &http.Client{Timeout: 8 * time.Second}
	for name, id := range catalogGifIDs {
		url := staticGIFMediaBase + id + ".gif"
		req, err := http.NewRequest(http.MethodGet, url, nil)
		if err != nil {
			t.Fatal(err)
		}
		res, err := client.Do(req)
		if err != nil {
			t.Errorf("%s (%s): %v", name, id, err)
			continue
		}
		_, _ = io.Copy(io.Discard, res.Body)
		res.Body.Close()
		if res.StatusCode != http.StatusOK {
			t.Errorf("%s id=%s: status %d", name, id, res.StatusCode)
		}
	}
}

func TestResolveUsesStaticWithoutIndex(t *testing.T) {
	// Block ExerciseDB API; static map must still resolve Squat.
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "blocked", http.StatusServiceUnavailable)
	}))
	defer srv.Close()

	svc := NewService(NewClient(srv.URL), true)
	url, err := svc.resolve(context.Background(), "Squat", "barbell")
	if err != nil || url == "" {
		t.Fatalf("resolve Squat = %q err=%v", url, err)
	}
	if url != staticGIFMediaBase+"qXTaZnJ.gif" {
		t.Fatalf("got %q", url)
	}
}
