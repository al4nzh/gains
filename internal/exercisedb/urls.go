package exercisedb

import "strings"

// gifMediaBase is the working CDN host for OSS ExerciseDB GIFs.
// The API still returns https://static.exercisedb.dev/... but that host no longer resolves.
const gifMediaBase = "https://exercisedb.dev/media/"

// NormalizeGIFURL rewrites broken static.exercisedb.dev links to exercisedb.dev.
func NormalizeGIFURL(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return ""
	}
	const broken = "https://static.exercisedb.dev/"
	if strings.HasPrefix(raw, broken) {
		return gifMediaBase + strings.TrimPrefix(raw, broken+"media/")
	}
	const brokenHTTP = "http://static.exercisedb.dev/"
	if strings.HasPrefix(raw, brokenHTTP) {
		return gifMediaBase + strings.TrimPrefix(raw, brokenHTTP+"media/")
	}
	return raw
}
