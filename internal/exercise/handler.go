package exercise

import (
	"net/http"
	"strconv"
	"strings"
	"unicode/utf8"

	"github.com/gin-gonic/gin"

	"gainsai/internal/auth"
)

const (
	defaultListLimit = 50
	maxListLimit     = 100
	maxSearchLimit   = 50
	maxQueryLen      = 80
)

type Handler struct {
	repo *Repository
}

func NewHandler(repo *Repository) *Handler {
	return &Handler{repo: repo}
}

func (h *Handler) RegisterRoutes(r *gin.Engine, requireAuth, limiter gin.HandlerFunc) {
	g := r.Group("/exercises", requireAuth, limiter)
	g.GET("", h.list)
	g.GET("/search", h.search)
}

func (h *Handler) list(c *gin.Context) {
	if _, ok := auth.UserIDFromContext(c); !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	limit := parsePositiveInt(c.DefaultQuery("limit", strconv.Itoa(defaultListLimit)), defaultListLimit, maxListLimit)
	offset := parseNonNegativeInt(c.DefaultQuery("offset", "0"), 0, 10_000)

	items, err := h.repo.ListCatalog(c.Request.Context(), limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	if items == nil {
		items = []Exercise{}
	}
	c.JSON(http.StatusOK, gin.H{"exercises": items})
}

func (h *Handler) search(c *gin.Context) {
	if _, ok := auth.UserIDFromContext(c); !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	q := strings.TrimSpace(c.Query("q"))
	if q == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "query parameter q is required"})
		return
	}
	if utf8.RuneCountInString(q) > maxQueryLen {
		c.JSON(http.StatusBadRequest, gin.H{"error": "q must be at most 80 characters"})
		return
	}
	limit := parsePositiveInt(c.DefaultQuery("limit", strconv.Itoa(maxSearchLimit)), maxSearchLimit, maxSearchLimit)

	items, err := h.repo.SearchCatalog(c.Request.Context(), q, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	if items == nil {
		items = []Exercise{}
	}
	c.JSON(http.StatusOK, gin.H{"exercises": items, "q": q})
}

func parsePositiveInt(s string, def, max int) int {
	n, err := strconv.Atoi(strings.TrimSpace(s))
	if err != nil || n < 1 {
		return def
	}
	if n > max {
		return max
	}
	return n
}

func parseNonNegativeInt(s string, def, max int) int {
	n, err := strconv.Atoi(strings.TrimSpace(s))
	if err != nil || n < 0 {
		return def
	}
	if n > max {
		return max
	}
	return n
}
