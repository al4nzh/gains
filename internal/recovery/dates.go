package recovery

import (
	"strings"
	"time"
)

// ParseLogicalDate parses YYYY-MM-DD as a calendar date (no timezone shift on the day).
func ParseLogicalDate(s string) (time.Time, error) {
	s = strings.TrimSpace(s)
	t, err := time.Parse("2006-01-02", s)
	if err != nil {
		return time.Time{}, err
	}
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC), nil
}

// TodayUTC returns today's calendar date in UTC (fallback when the client omits checkin_date).
func TodayUTC() time.Time {
	now := time.Now().UTC()
	return time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
}

func formatLogicalDate(t time.Time) string {
	return t.UTC().Format("2006-01-02")
}
