package subscription

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"gainsai/internal/auth"
	"gainsai/internal/user"
)

type Handler struct {
	users      *user.Repository
	revenueCat *RevenueCatClient
}

func NewHandler(users *user.Repository, revenueCat *RevenueCatClient) *Handler {
	return &Handler{users: users, revenueCat: revenueCat}
}

func (h *Handler) RegisterRoutes(r *gin.Engine, requireAuth gin.HandlerFunc) {
	r.GET("/subscription", requireAuth, h.status)
	r.POST("/subscription/sync", requireAuth, h.sync)
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
		IsPremium:       u.IsPremium,
		PremiumFeatures: premiumFeatures(),
		FreeFeatures:    freeFeatures(),
	})
}

func (h *Handler) sync(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	if h.revenueCat == nil || !h.revenueCat.Configured() {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "subscription sync not configured"})
		return
	}

	premium, err := h.revenueCat.HasActiveEntitlement(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": "could not verify subscription"})
		return
	}
	if err := h.users.SetPremium(c.Request.Context(), userID, premium); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true, "is_premium": premium})
}

func premiumFeatures() []string {
	return []string{
		"ai_coach",
		"workout_analysis",
		"routine_generation",
		"physique_scans",
		"gym_archetype",
		"adaptive_recommendations",
		"train_next",
	}
}

func freeFeatures() []string {
	return []string{
		"workouts",
		"routines",
		"templates",
		"progress",
		"strength_elo",
		"recovery_log",
	}
}
