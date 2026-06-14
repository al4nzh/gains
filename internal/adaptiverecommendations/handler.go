package adaptiverecommendations

import (
	"errors"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"gainsai/internal/aiquota"
	"gainsai/internal/auth"
	"gainsai/internal/subscription"
	"gainsai/internal/user"
)

type Handler struct {
	svc   *Service
	users *user.Repository
}

func NewHandler(svc *Service, users *user.Repository) *Handler {
	return &Handler{svc: svc, users: users}
}

func (h *Handler) RegisterRoutes(r *gin.Engine, requireAuth, limiter gin.HandlerFunc) {
	g := r.Group("/adaptive-recommendations", requireAuth, limiter)
	g.GET("/routine/:routineId", h.forRoutine)
	g.POST("/apply", h.apply)
}

func (h *Handler) forRoutine(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	if err := subscription.RequirePremium(c.Request.Context(), h.users, userID); err != nil {
		if aiquota.WriteError(c, err) {
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	rid := strings.TrimSpace(c.Param("routineId"))
	out, err := h.svc.ForRoutine(c.Request.Context(), userID, rid)
	if err != nil {
		mapErr(c, err)
		return
	}
	if out.Recommendations == nil {
		out.Recommendations = []Recommendation{}
	}
	c.JSON(http.StatusOK, out)
}

type applyBody struct {
	WorkoutID          string `json:"workout_id" binding:"required"`
	RecommendationID   string `json:"recommendation_id" binding:"required"`
}

func (h *Handler) apply(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	if err := subscription.RequirePremium(c.Request.Context(), h.users, userID); err != nil {
		if aiquota.WriteError(c, err) {
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	var body applyBody
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	out, err := h.svc.Apply(c.Request.Context(), userID, strings.TrimSpace(body.WorkoutID), strings.TrimSpace(body.RecommendationID))
	if err != nil {
		mapErr(c, err)
		return
	}
	c.JSON(http.StatusOK, out)
}

func mapErr(c *gin.Context, err error) {
	switch {
	case errors.Is(err, ErrRoutineNotYours), errors.Is(err, ErrWorkoutNotYours), errors.Is(err, ErrNotFound):
		c.JSON(http.StatusNotFound, gin.H{"error": "not found"})
	case errors.Is(err, ErrWorkoutNotActive):
		c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
	case errors.Is(err, ErrRecommendationUnknown):
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
	case errors.Is(err, ErrAlreadyApplied):
		c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
	default:
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
	}
}
