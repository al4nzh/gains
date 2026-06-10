package subscription

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"gainsai/internal/auth"
	"gainsai/internal/user"
)

type Handler struct {
	users *user.Repository
}

func NewHandler(users *user.Repository) *Handler {
	return &Handler{users: users}
}

func (h *Handler) RegisterRoutes(r *gin.Engine, requireAuth gin.HandlerFunc) {
	r.GET("/subscription", requireAuth, h.status)
}

type statusResponse struct {
	IsPremium       bool     `json:"is_premium"`
	PremiumFeatures []string `json:"premium_features"`
	FreeFeatures    []string `json:"free_features"`
}

func (h *Handler) status(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	u, err := h.users.GetByID(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	c.JSON(http.StatusOK, statusResponse{
		IsPremium: u.IsPremium,
		PremiumFeatures: []string{
			"ai_coach",
			"workout_analysis",
			"routine_generation",
			"physique_scans",
		},
		FreeFeatures: []string{
			"workouts",
			"routines",
			"templates",
			"progress",
			"strength_elo",
			"gym_archetype",
			"recovery_log",
			"adaptive_recommendations",
		},
	})
}
