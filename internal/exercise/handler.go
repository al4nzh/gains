package exercise

import (
	"net/http"
	"strconv"
	"strings"
	"unicode/utf8"

	"github.com/gin-gonic/gin"

	"gainsai/internal/auth"
	"gainsai/internal/exercisedb"
)

const (
	defaultListLimit   = 50
	maxListLimit       = 100
	maxSearchLimit     = 50
	maxQueryLen        = 80
	maxGifLookupIDs    = 40
)

type Handler struct {
	repo          *Repository
	gifSvc        *exercisedb.Service
	publicAPIBase string
}

func NewHandler(repo *Repository, gifSvc *exercisedb.Service, publicAPIBase string) *Handler {
	return &Handler{repo: repo, gifSvc: gifSvc, publicAPIBase: strings.TrimRight(strings.TrimSpace(publicAPIBase), "/")}
}

func (h *Handler) RegisterRoutes(r *gin.Engine, requireAuth, limiter gin.HandlerFunc) {
	g := r.Group("/exercises", requireAuth, limiter)
	g.GET("", h.list)
	g.GET("/search", h.search)
	g.POST("/gifs", h.lookupGifs)
}

func (h *Handler) list(c *gin.Context) {
	if _, ok := auth.UserIDFromContext(c); !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	muscleGroup, ok := normalizeCatalogMuscleGroup(c.Query("muscle_group"))
	if !ok {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid muscle_group"})
		return
	}
	limit := parsePositiveInt(c.DefaultQuery("limit", strconv.Itoa(defaultListLimit)), defaultListLimit, maxListLimit)
	offset := parseNonNegativeInt(c.DefaultQuery("offset", "0"), 0, 10_000)

	items, err := h.repo.ListCatalog(c.Request.Context(), muscleGroup, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	if items == nil {
		items = []Exercise{}
	}
	resp := gin.H{"exercises": items}
	if muscleGroup != "" {
		resp["muscle_group"] = muscleGroup
	}
	c.JSON(http.StatusOK, resp)
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
	muscleGroup, ok := normalizeCatalogMuscleGroup(c.Query("muscle_group"))
	if !ok {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid muscle_group"})
		return
	}
	limit := parsePositiveInt(c.DefaultQuery("limit", strconv.Itoa(maxSearchLimit)), maxSearchLimit, maxSearchLimit)

	items, err := h.repo.SearchCatalog(c.Request.Context(), q, muscleGroup, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	if items == nil {
		items = []Exercise{}
	}
	resp := gin.H{"exercises": items, "q": q}
	if muscleGroup != "" {
		resp["muscle_group"] = muscleGroup
	}
	c.JSON(http.StatusOK, resp)
}

type gifLookupRequest struct {
	ExerciseIDs []string `json:"exercise_ids"`
}

func (h *Handler) lookupGifs(c *gin.Context) {
	if _, ok := auth.UserIDFromContext(c); !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	if h.gifSvc == nil || !h.gifSvc.Enabled() {
		c.JSON(http.StatusOK, gin.H{"gifs": gin.H{}})
		return
	}
	var req gifLookupRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}
	ids := uniqueNonEmpty(req.ExerciseIDs, maxGifLookupIDs)
	if len(ids) == 0 {
		c.JSON(http.StatusOK, gin.H{"gifs": gin.H{}})
		return
	}
	meta, err := h.repo.GetLookupMetaByIDs(c.Request.Context(), ids)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	items := make([]exercisedb.LookupItem, 0, len(meta))
	for _, id := range ids {
		m, ok := meta[id]
		if !ok {
			continue
		}
		items = append(items, exercisedb.LookupItem{
			ID:        m.ID,
			Name:      m.Name,
			Equipment: m.Equipment,
		})
	}
	gifs := h.gifSvc.LookupGIFs(c.Request.Context(), items)
	if h.publicAPIBase != "" {
		for id, url := range gifs {
			gifs[id] = exercisedb.ToProxyGIFURL(h.publicAPIBase, url)
		}
	}
	c.JSON(http.StatusOK, gin.H{"gifs": gifs})
}

func uniqueNonEmpty(ids []string, max int) []string {
	seen := make(map[string]struct{}, len(ids))
	out := make([]string, 0, len(ids))
	for _, id := range ids {
		id = strings.TrimSpace(id)
		if id == "" {
			continue
		}
		if _, ok := seen[id]; ok {
			continue
		}
		seen[id] = struct{}{}
		out = append(out, id)
		if len(out) >= max {
			break
		}
	}
	return out
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
