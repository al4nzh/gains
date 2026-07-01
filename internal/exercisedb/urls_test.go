package exercisedb

import "testing"

func TestNormalizeGIFURL(t *testing.T) {
	t.Parallel()
	in := "https://static.exercisedb.dev/media/EIeI8Vf.gif"
	want := "https://exercisedb.dev/media/EIeI8Vf.gif"
	if got := NormalizeGIFURL(in); got != want {
		t.Fatalf("got %q want %q", got, want)
	}
}
