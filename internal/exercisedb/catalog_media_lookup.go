package exercisedb

import "strings"

// CatalogSearchNameForMediaID returns a catalog label to search AscendAPI for a static media id.
func CatalogSearchNameForMediaID(mediaID string) string {
	mediaID = strings.TrimSpace(mediaID)
	if mediaID == "" {
		return ""
	}
	for name, id := range catalogGifIDs {
		if id == mediaID {
			return name
		}
	}
	return ""
}
