package workout

import (
	"errors"
	"net/http"
	"strings"

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
	g := r.Group("/workouts", requireAuth, limiter)
	g.POST("", h.start)
	g.GET("", h.list)
	g.GET("/:id", h.get)
	g.POST("/:id/sets", h.addSet)
	g.PUT("/:id/sets/:setId", h.updateSet)
	g.DELETE("/:id/sets/:setId", h.deleteSet)
	g.POST("/:id/finish", h.finish)
}

type startWorkoutBody struct {
	RoutineID *string `json:"routine_id"`
	Name      *string `json:"name"`
}

func (h *Handler) start(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	var body startWorkoutBody
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	w, err := h.svc.StartWorkout(c.Request.Context(), userID, body.RoutineID, body.Name)
	if err != nil {
		mapWorkoutErr(c, err)
		return
	}
	w.Sets = []SetOut{}
	c.JSON(http.StatusCreated, w)
}

func (h *Handler) list(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	list, err := h.svc.ListWorkouts(c.Request.Context(), userID, 30)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	if list == nil {
		list = []Workout{}
	}
	c.JSON(http.StatusOK, gin.H{"workouts": list})
}

func (h *Handler) get(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	id := strings.TrimSpace(c.Param("id"))
	w, err := h.svc.GetWorkout(c.Request.Context(), userID, id)
	if err != nil {
		mapWorkoutErr(c, err)
		return
	}
	c.JSON(http.StatusOK, w)
}

type addSetBody struct {
	ExerciseID string   `json:"exercise_id" binding:"required"`
	SetNumber  *int     `json:"set_number"`
	Reps       *int     `json:"reps" binding:"required"`
	WeightKg   *float64 `json:"weight_kg" binding:"required"`
	RPE        *float64 `json:"rpe"`
	IsFailure  bool     `json:"is_failure"`
	Notes      *string  `json:"notes"`
}

func (h *Handler) addSet(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	var body addSetBody
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	wid := strings.TrimSpace(c.Param("id"))
	out, err := h.svc.AddSet(c.Request.Context(), userID, wid, AddSetInput{
		ExerciseID: body.ExerciseID,
		SetNumber:  body.SetNumber,
		Reps:       body.Reps,
		WeightKg:   body.WeightKg,
		RPE:        body.RPE,
		IsFailure:  body.IsFailure,
		Notes:      body.Notes,
	})
	if err != nil {
		mapWorkoutErr(c, err)
		return
	}
	c.JSON(http.StatusCreated, out)
}

type updateSetBody struct {
	Reps      *int     `json:"reps"`
	WeightKg  *float64 `json:"weight_kg"`
	RPE       *float64 `json:"rpe"`
	IsFailure *bool    `json:"is_failure"`
	Notes     *string  `json:"notes"`
}

func (h *Handler) updateSet(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	var body updateSetBody
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	wid := strings.TrimSpace(c.Param("id"))
	sid := strings.TrimSpace(c.Param("setId"))
	out, err := h.svc.UpdateSet(c.Request.Context(), userID, wid, sid, UpdateSetInput{
		Reps:      body.Reps,
		WeightKg:  body.WeightKg,
		RPE:       body.RPE,
		IsFailure: body.IsFailure,
		Notes:     body.Notes,
	})
	if err != nil {
		mapWorkoutErr(c, err)
		return
	}
	c.JSON(http.StatusOK, out)
}

func (h *Handler) deleteSet(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	wid := strings.TrimSpace(c.Param("id"))
	sid := strings.TrimSpace(c.Param("setId"))
	if err := h.svc.DeleteSet(c.Request.Context(), userID, wid, sid); err != nil {
		mapWorkoutErr(c, err)
		return
	}
	c.Status(http.StatusNoContent)
}

type finishBody struct {
	Notes *string `json:"notes"`
}

func (h *Handler) finish(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	var body finishBody
	_ = c.ShouldBindJSON(&body)
	wid := strings.TrimSpace(c.Param("id"))
	stats, err := h.svc.FinishWorkout(c.Request.Context(), userID, wid, FinishInput{Notes: body.Notes})
	if err != nil {
		mapWorkoutErr(c, err)
		return
	}
	c.JSON(http.StatusOK, stats)
}

func mapWorkoutErr(c *gin.Context, err error) {
	if err == nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	switch {
	case errors.Is(err, ErrNotFound), errors.Is(err, ErrExerciseNotFound), errors.Is(err, ErrSetNotFound), errors.Is(err, ErrRoutineNotYours):
		c.JSON(http.StatusNotFound, gin.H{"error": "not found"})
	case errors.Is(err, ErrAlreadyFinished):
		c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
	case errors.Is(err, ErrInvalidSetPayload):
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
	default:
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
	}
}
