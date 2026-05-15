package ai

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"gainsai/internal/auth"
)

type Handler struct {
	svc *Service
}

func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

func (h *Handler) RegisterRoutes(r *gin.Engine, requireAuth, limiter gin.HandlerFunc) {
	g := r.Group("/ai", requireAuth, limiter)
	g.POST("/analyze-workout/:workoutId", h.analyzeWorkout)
	g.GET("/insights", h.listInsights)
}

func (h *Handler) analyzeWorkout(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	workoutID := c.Param("workoutId")
	out, err := h.svc.AnalyzeWorkout(c.Request.Context(), userID, workoutID)
	if err != nil {
		switch {
		case errors.Is(err, ErrNotFound):
			c.JSON(http.StatusNotFound, gin.H{"error": "workout not found"})
		case errors.Is(err, ErrWorkoutNotCompleted):
			c.JSON(http.StatusBadRequest, gin.H{"error": "workout is not completed"})
		case errors.Is(err, ErrOpenAINotConfigured):
			c.JSON(http.StatusServiceUnavailable, gin.H{"error": "AI is not configured (set OPENAI_API_KEY)"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		}
		return
	}
	c.JSON(http.StatusOK, out)
}

func (h *Handler) listInsights(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	limit := 50
	if q := c.Query("limit"); q != "" {
		if n, err := strconv.Atoi(q); err == nil {
			limit = n
		}
	}
	out, err := h.svc.ListInsights(c.Request.Context(), userID, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"insights": out})
}
