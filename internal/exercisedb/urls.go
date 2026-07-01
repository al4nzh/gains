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

// ExtractGIFMediaID returns the ExerciseDB media id from a GIF URL, if present.
func ExtractGIFMediaID(raw string) string {
	raw = NormalizeGIFURL(raw)
	const marker = "/media/"
	i := strings.LastIndex(raw, marker)
	if i < 0 {
		return ""
	}
	id := strings.TrimSuffix(raw[i+len(marker):], ".gif")
	id = strings.TrimSpace(id)
	if id == "" || strings.Contains(id, "/") {
		return ""
	}
	return id
}

// ProxyGIFURL builds a public API URL that proxies an ExerciseDB GIF.
func ProxyGIFURL(publicAPIBase, mediaID string) string {
	publicAPIBase = strings.TrimRight(strings.TrimSpace(publicAPIBase), "/")
	mediaID = strings.TrimSpace(mediaID)
	mediaID = strings.TrimSuffix(mediaID, ".gif")
	if publicAPIBase == "" || mediaID == "" {
		return ""
	}
	return publicAPIBase + "/media/exercise-gifs/" + mediaID + ".gif"
}

// ToProxyGIFURL normalizes a GIF URL and rewrites it to the API proxy when possible.
func ToProxyGIFURL(publicAPIBase, raw string) string {
	if id := ExtractGIFMediaID(raw); id != "" {
		if proxy := ProxyGIFURL(publicAPIBase, id); proxy != "" {
			return proxy
		}
	}
	return NormalizeGIFURL(raw)
}
