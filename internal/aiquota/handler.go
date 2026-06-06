package aiquota

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
)

// WriteError maps quota errors to HTTP responses. Returns true if err was handled.
func WriteError(c *gin.Context, err error) bool {
	switch {
	case errors.Is(err, ErrPremiumRequired):
		c.JSON(http.StatusForbidden, gin.H{"error": "premium subscription required for AI features"})
		return true
	case errors.Is(err, ErrDailyQuotaExceeded):
		c.JSON(http.StatusTooManyRequests, gin.H{"error": "daily AI limit reached — try again tomorrow"})
		return true
	default:
		return false
	}
}
