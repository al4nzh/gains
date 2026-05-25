package routine

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
	tg := r.Group("/routine-templates", requireAuth, limiter)
	tg.GET("", h.listTemplates)
	tg.POST("/:id/copy", h.copyTemplate)
	tg.GET("/:id", h.getTemplate)

	g := r.Group("/routines", requireAuth, limiter)
	g.POST("", h.createRoutine)
	g.GET("", h.listRoutines)
	g.GET("/:id", h.getRoutine)
	g.PUT("/:id", h.updateRoutine)
	g.DELETE("/:id", h.deleteRoutine)
	g.POST("/:id/exercises", h.addExercise)
	g.PUT("/:id/exercises/:routineExerciseId", h.updateExercise)
	g.DELETE("/:id/exercises/:routineExerciseId", h.deleteExercise)
}

type createRoutineBody struct {
	Name        string  `json:"name"`
	Description *string `json:"description"`
}

func (h *Handler) createRoutine(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	var body createRoutineBody
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	out, err := h.svc.CreateRoutine(c.Request.Context(), userID, body.Name, body.Description)
	if err != nil {
		mapRoutineErr(c, err)
		return
	}
	out.Exercises = []RoutineExerciseOut{}
	c.JSON(http.StatusCreated, out)
}

func (h *Handler) listRoutines(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	list, err := h.svc.ListMyRoutines(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	if list == nil {
		list = []Routine{}
	}
	c.JSON(http.StatusOK, gin.H{"routines": list})
}

func (h *Handler) getRoutine(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	id := strings.TrimSpace(c.Param("id"))
	out, err := h.svc.GetRoutineDetail(c.Request.Context(), userID, id)
	if err != nil {
		mapRoutineErr(c, err)
		return
	}
	c.JSON(http.StatusOK, out)
}

type updateRoutineBody struct {
	Name        *string `json:"name"`
	Description *string `json:"description"`
}

func (h *Handler) updateRoutine(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	var body updateRoutineBody
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if body.Name == nil && body.Description == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "provide name and/or description"})
		return
	}
	id := strings.TrimSpace(c.Param("id"))
	if _, err := h.svc.UpdateRoutine(c.Request.Context(), userID, id, body.Name, body.Description); err != nil {
		mapRoutineErr(c, err)
		return
	}
	detail, err := h.svc.GetRoutineDetail(c.Request.Context(), userID, id)
	if err != nil {
		mapRoutineErr(c, err)
		return
	}
	c.JSON(http.StatusOK, detail)
}

func (h *Handler) deleteRoutine(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	rid := strings.TrimSpace(c.Param("id"))
	if err := h.svc.DeleteRoutine(c.Request.Context(), userID, rid); err != nil {
		mapRoutineErr(c, err)
		return
	}
	c.Status(http.StatusNoContent)
}

type addExerciseBody struct {
	ExerciseID   string   `json:"exercise_id" binding:"required"`
	TargetSets   *int     `json:"target_sets"`
	TargetRepMin *int     `json:"target_rep_min"`
	TargetRepMax *int     `json:"target_rep_max"`
	TargetRPE    *float64 `json:"target_rpe"`
	RestSeconds  *int     `json:"rest_seconds"`
	Notes        *string  `json:"notes"`
	Position     *int     `json:"position"`
}

func (h *Handler) addExercise(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	var body addExerciseBody
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	rid := strings.TrimSpace(c.Param("id"))
	out, err := h.svc.AddRoutineExercise(c.Request.Context(), userID, rid, AddRoutineExerciseInput{
		ExerciseID:   body.ExerciseID,
		TargetSets:   body.TargetSets,
		TargetRepMin: body.TargetRepMin,
		TargetRepMax: body.TargetRepMax,
		TargetRPE:    body.TargetRPE,
		RestSeconds:  body.RestSeconds,
		Notes:        body.Notes,
		Position:     body.Position,
	})
	if err != nil {
		mapRoutineErr(c, err)
		return
	}
	c.JSON(http.StatusCreated, out)
}

type updateExerciseBody struct {
	TargetSets   *int     `json:"target_sets"`
	TargetRepMin *int     `json:"target_rep_min"`
	TargetRepMax *int     `json:"target_rep_max"`
	TargetRPE    *float64 `json:"target_rpe"`
	RestSeconds  *int     `json:"rest_seconds"`
	Notes        *string  `json:"notes"`
	Position     *int     `json:"position"`
}

func (h *Handler) updateExercise(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	var body updateExerciseBody
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	rid := strings.TrimSpace(c.Param("id"))
	rowID := strings.TrimSpace(c.Param("routineExerciseId"))
	out, err := h.svc.UpdateRoutineExercise(c.Request.Context(), userID, rid, rowID, UpdateRoutineExerciseInput{
		TargetSets:   body.TargetSets,
		TargetRepMin: body.TargetRepMin,
		TargetRepMax: body.TargetRepMax,
		TargetRPE:    body.TargetRPE,
		RestSeconds:  body.RestSeconds,
		Notes:        body.Notes,
		Position:     body.Position,
	})
	if err != nil {
		mapRoutineErr(c, err)
		return
	}
	c.JSON(http.StatusOK, out)
}

func (h *Handler) deleteExercise(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	rid := strings.TrimSpace(c.Param("id"))
	rowID := strings.TrimSpace(c.Param("routineExerciseId"))
	if err := h.svc.DeleteRoutineExercise(c.Request.Context(), userID, rid, rowID); err != nil {
		mapRoutineErr(c, err)
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) listTemplates(c *gin.Context) {
	if _, ok := auth.UserIDFromContext(c); !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	list, err := h.svc.ListTemplates(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	if list == nil {
		list = []RoutineTemplate{}
	}
	c.JSON(http.StatusOK, gin.H{"templates": list})
}

func (h *Handler) getTemplate(c *gin.Context) {
	if _, ok := auth.UserIDFromContext(c); !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	id := strings.TrimSpace(c.Param("id"))
	out, err := h.svc.GetTemplateDetail(c.Request.Context(), id)
	if err != nil {
		mapRoutineErr(c, err)
		return
	}
	c.JSON(http.StatusOK, out)
}

type copyTemplateBody struct {
	Name *string `json:"name"`
}

func (h *Handler) copyTemplate(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	var body copyTemplateBody
	_ = c.ShouldBindJSON(&body)
	id := strings.TrimSpace(c.Param("id"))
	out, err := h.svc.CopyTemplate(c.Request.Context(), userID, id, body.Name)
	if err != nil {
		mapRoutineErr(c, err)
		return
	}
	out.Exercises = []RoutineExerciseOut{}
	c.JSON(http.StatusCreated, out)
}

func mapRoutineErr(c *gin.Context, err error) {
	if err == nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	switch {
	case errors.Is(err, ErrNotFound), errors.Is(err, ErrTemplateNotFound), errors.Is(err, ErrExerciseNotFound), errors.Is(err, ErrRoutineExerciseNotFound):
		c.JSON(http.StatusNotFound, gin.H{"error": "not found"})
	case errors.Is(err, ErrInvalidPosition):
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
	default:
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
	}
}
