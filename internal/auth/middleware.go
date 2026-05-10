package auth

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

const (
	ContextUserID = "auth_user_id"
	ContextEmail  = "auth_email"
)

func RequireAuth(jwt *JWTIssuer) gin.HandlerFunc {
	return func(c *gin.Context) {
		h := c.GetHeader("Authorization")
		if h == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "missing authorization header"})
			return
		}
		const prefix = "Bearer "
		if !strings.HasPrefix(h, prefix) {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid authorization header"})
			return
		}
		tokenStr := strings.TrimPrefix(h, prefix)
		claims, err := jwt.Parse(tokenStr)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid or expired token"})
			return
		}
		c.Set(ContextUserID, claims.UserID)
		c.Set(ContextEmail, claims.Email)
		c.Next()
	}
}

func UserIDFromContext(c *gin.Context) (string, bool) {
	v, ok := c.Get(ContextUserID)
	if !ok {
		return "", false
	}
	s, ok := v.(string)
	return s, ok
}
