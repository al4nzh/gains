package ai

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgconn"

	"gainsai/internal/auth"
	"gainsai/internal/routine"
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
	g.POST("/chat", h.chat)
	g.GET("/chat/conversations", h.listChatConversations)
	g.GET("/chat/conversations/:conversationId/messages", h.getChatMessages)
	g.DELETE("/chat/conversations/:conversationId", h.deleteChatConversation)
	g.GET("/actions/pending", h.listPendingActions)
	g.POST("/actions/:id/accept", h.acceptAction)
	g.POST("/actions/:id/reject", h.rejectAction)
	g.POST("/generate-routines", h.generateRoutines)
	g.POST("/generated-routines/:draftId/confirm", h.confirmGeneratedRoutines)
}

func (h *Handler) generateRoutines(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	var req GenerateRoutinesRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}
	out, err := h.svc.GenerateRoutineDraft(c.Request.Context(), userID, req)
	if err != nil {
		switch {
		case errors.Is(err, ErrRoutineGenMessageRequired):
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		case errors.Is(err, ErrOpenAINotConfigured):
			c.JSON(http.StatusServiceUnavailable, gin.H{"error": "AI is not configured (set OPENAI_API_KEY)"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		}
		return
	}
	c.JSON(http.StatusOK, out)
}

func (h *Handler) confirmGeneratedRoutines(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	out, err := h.svc.ConfirmRoutineDraft(c.Request.Context(), userID, c.Param("draftId"))
	if err != nil {
		switch {
		case errors.Is(err, ErrRoutineDraftNotFound):
			c.JSON(http.StatusNotFound, gin.H{"error": "draft not found"})
		case errors.Is(err, ErrRoutineDraftNotPending):
			c.JSON(http.StatusConflict, gin.H{"error": "draft already confirmed or not available"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		}
		return
	}
	c.JSON(http.StatusOK, out)
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

func (h *Handler) chat(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	var req ChatRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}
	out, err := h.svc.Chat(c.Request.Context(), userID, req)
	if err != nil {
		switch {
		case errors.Is(err, ErrChatMessageRequired):
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		case errors.Is(err, ErrConversationNotFound):
			c.JSON(http.StatusNotFound, gin.H{"error": "conversation not found"})
		case errors.Is(err, ErrOpenAINotConfigured):
			c.JSON(http.StatusServiceUnavailable, gin.H{"error": "AI is not configured (set OPENAI_API_KEY)"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		}
		return
	}
	c.JSON(http.StatusOK, out)
}

func (h *Handler) listChatConversations(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	limit := 30
	if q := c.Query("limit"); q != "" {
		if n, err := strconv.Atoi(q); err == nil {
			limit = n
		}
	}
	out, err := h.svc.ListChatConversations(c.Request.Context(), userID, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	c.JSON(http.StatusOK, out)
}

func (h *Handler) listPendingActions(c *gin.Context) {
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
	out, err := h.svc.ListPendingActions(c.Request.Context(), userID, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"actions": out})
}

func (h *Handler) acceptAction(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	out, err := h.svc.AcceptAction(c.Request.Context(), userID, c.Param("id"))
	if err != nil {
		writeActionError(c, err)
		return
	}
	c.JSON(http.StatusOK, out)
}

func (h *Handler) rejectAction(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	out, err := h.svc.RejectAction(c.Request.Context(), userID, c.Param("id"))
	if err != nil {
		writeActionError(c, err)
		return
	}
	c.JSON(http.StatusOK, out)
}

func writeActionError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, ErrActionNotFound):
		c.JSON(http.StatusNotFound, gin.H{"error": "action not found"})
	case errors.Is(err, ErrActionNotPending):
		c.JSON(http.StatusConflict, gin.H{"error": "action is not pending"})
	case errors.Is(err, ErrUnsupportedAction):
		c.JSON(http.StatusBadRequest, gin.H{"error": "unsupported action type"})
	case errors.Is(err, ErrActionValidation), errors.Is(err, ErrExerciseNotResolved):
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
	case errors.Is(err, routine.ErrNotFound), errors.Is(err, routine.ErrRoutineExerciseNotFound), errors.Is(err, routine.ErrExerciseNotFound):
		c.JSON(http.StatusBadRequest, gin.H{"error": "target no longer exists"})
	default:
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "conflicting routine exercise order"})
			return
		}
		if msg := err.Error(); msg != "" && msg != "internal error" {
			c.JSON(http.StatusBadRequest, gin.H{"error": msg})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
	}
}

func (h *Handler) getChatMessages(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	convID := c.Param("conversationId")
	out, err := h.svc.GetChatMessages(c.Request.Context(), userID, convID)
	if err != nil {
		if errors.Is(err, ErrConversationNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "conversation not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	c.JSON(http.StatusOK, out)
}

func (h *Handler) deleteChatConversation(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	convID := c.Param("conversationId")
	if err := h.svc.DeleteChatConversation(c.Request.Context(), userID, convID); err != nil {
		if errors.Is(err, ErrConversationNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "conversation not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	c.Status(http.StatusNoContent)
}
