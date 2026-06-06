package auth

import (
	"errors"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"gainsai/internal/user"
)

const (
	ContextUserID = "auth_user_id"
	ContextEmail  = "auth_email"
)

var ErrEmailNotVerified = errors.New("email address not verified")

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

// emailAccountNeedsVerification is true for email/password users who have not verified yet.
func emailAccountNeedsVerification(u *user.User) bool {
	return u != nil && u.AuthProvider == user.AuthProviderEmail && !u.EmailVerified()
}

// RequireVerifiedEmail blocks email/password users until email_verified_at is set.
// OAuth users pass through. Must run after RequireAuth.
func RequireVerifiedEmail(users *user.Repository) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, ok := UserIDFromContext(c)
		if !ok {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
			return
		}
		u, err := users.GetByID(c.Request.Context(), userID)
		if err != nil {
			if errors.Is(err, user.ErrNotFound) {
				c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
				return
			}
			c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
			return
		}
		if emailAccountNeedsVerification(u) {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "verify your email before using the app"})
			return
		}
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
