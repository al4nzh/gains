package recovery

import "testing"

func TestParseLogicalDate(t *testing.T) {
	d, err := ParseLogicalDate("2026-05-12")
	if err != nil {
		t.Fatal(err)
	}
	if formatLogicalDate(d) != "2026-05-12" {
		t.Fatalf("got %q", formatLogicalDate(d))
	}
}
