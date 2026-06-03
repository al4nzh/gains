package strength

import "math"

// MinRatedForPercentile avoids misleading ranks when almost no one has Elo yet.
const MinRatedForPercentile = 5

// PercentileFromCounts returns the share of rated lifters with strictly lower Elo (0–100).
// ok is false when [total] is below [MinRatedForPercentile].
func PercentileFromCounts(below, total int) (percentile int, ok bool) {
	if total < MinRatedForPercentile {
		return 0, false
	}
	if below <= 0 {
		return 0, true
	}
	if below >= total {
		return 100, true
	}
	p := int(math.Round(float64(below) * 100.0 / float64(total)))
	return clampInt(p, 0, 100), true
}

func clampInt(v, lo, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}
