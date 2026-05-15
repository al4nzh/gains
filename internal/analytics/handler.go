package analytics

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"

	"gainsai/internal/auth"
	"gainsai/internal/workout"
)

type Handler struct {
	svc *Service
}

func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

func (h *Handler) RegisterRoutes(r *gin.Engine, requireAuth, limiter gin.HandlerFunc) {
	authd := r.Group("", requireAuth, limiter)
	authd.GET("/home", h.home)

	g := r.Group("/analytics", requireAuth, limiter)
	g.GET("/exercises", h.exercisesList)
	g.GET("/exercises/:exerciseId", h.exerciseDetail)
	g.GET("/workouts/:workoutId/context", h.workoutContext)
	g.GET("/coach-context", h.coachContext)
}

func (h *Handler) home(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	out, err := h.svc.Home(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	c.JSON(http.StatusOK, out)
}

func (h *Handler) exercisesList(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	out, err := h.svc.Exercises(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	c.JSON(http.StatusOK, out)
}

func (h *Handler) exerciseDetail(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	exerciseID := c.Param("exerciseId")
	out, err := h.svc.ExerciseDetail(c.Request.Context(), userID, exerciseID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	c.JSON(http.StatusOK, out)
}

func (h *Handler) workoutContext(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	workoutID := c.Param("workoutId")
	out, err := h.svc.WorkoutContext(c.Request.Context(), userID, workoutID)
	if err != nil {
		if errors.Is(err, workout.ErrNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "workout not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	c.JSON(http.StatusOK, out)
}

func (h *Handler) coachContext(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	out, err := h.svc.CoachContext(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	c.JSON(http.StatusOK, out)
}
