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

func TestToProxyGIFURL(t *testing.T) {
	t.Parallel()
	in := "https://static.exercisedb.dev/media/EIeI8Vf.gif"
	want := "https://api.gainsai.net/media/exercise-gifs/EIeI8Vf.gif"
	if got := ToProxyGIFURL("https://api.gainsai.net", in); got != want {
		t.Fatalf("got %q want %q", got, want)
	}
}
