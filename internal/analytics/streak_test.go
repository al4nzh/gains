package analytics

import (
	"testing"
	"time"
)

func TestStreakFromDistinctDescDates(t *testing.T) {
	now := time.Date(2026, 5, 28, 15, 0, 0, 0, time.UTC)
	today := now.UTC().Truncate(24 * time.Hour)
	yesterday := today.AddDate(0, 0, -1)
	twoDaysAgo := today.AddDate(0, 0, -2)
	threeDaysAgo := today.AddDate(0, 0, -3)

	tests := []struct {
		name  string
		dates []time.Time
		want  int
	}{
		{name: "empty", dates: nil, want: 0},
		{name: "broken streak", dates: []time.Time{twoDaysAgo}, want: 0},
		{name: "today only", dates: []time.Time{today}, want: 1},
		{name: "yesterday only", dates: []time.Time{yesterday}, want: 1},
		{name: "today and yesterday", dates: []time.Time{today, yesterday}, want: 2},
		{name: "three consecutive ending yesterday", dates: []time.Time{yesterday, twoDaysAgo, threeDaysAgo}, want: 3},
		{name: "gap breaks count", dates: []time.Time{yesterday, threeDaysAgo}, want: 1},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := streakFromDistinctDescDates(tt.dates, now)
			if got != tt.want {
				t.Fatalf("streakFromDistinctDescDates() = %d, want %d", got, tt.want)
			}
		})
	}
}
