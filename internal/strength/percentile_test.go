package strength

import "testing"

func TestPercentileFromCounts(t *testing.T) {
	tests := []struct {
		below, total int
		want         int
		ok           bool
	}{
		{0, 4, 0, false},
		{0, 5, 0, true},
		{4, 5, 80, true},
		{99, 100, 99, true},
		{50, 100, 50, true},
		{100, 100, 100, true},
	}
	for _, tc := range tests {
		got, ok := PercentileFromCounts(tc.below, tc.total)
		if ok != tc.ok || got != tc.want {
			t.Errorf("PercentileFromCounts(%d,%d) = (%d,%v), want (%d,%v)", tc.below, tc.total, got, ok, tc.want, tc.ok)
		}
	}
}
