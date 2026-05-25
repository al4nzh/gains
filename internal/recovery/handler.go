package recovery

import (
	"errors"
	"net/http"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/gin-gonic/gin"

	"gainsai/internal/auth"
)

type Handler struct {
	repo *Repository
}

func NewHandler(repo *Repository) *Handler {
	return &Handler{repo: repo}
}

func (h *Handler) RegisterRoutes(r *gin.Engine, requireAuth, limiter gin.HandlerFunc) {
	g := r.Group("/recovery-checkins", requireAuth, limiter)
	g.POST("", h.create)
	g.GET("/latest", h.latest)
	g.GET("/status", h.status)
	g.GET("", h.list)
}

type createBody struct {
	CheckinDate     *string `json:"checkin_date"` // YYYY-MM-DD local calendar date; default today UTC
	SleepHours      float64 `json:"sleep_hours"`  // 0–24
	EnergyReadiness int     `json:"energy_readiness"`
	CaloriesKcal    int     `json:"calories_kcal"`
	ProteinG        int     `json:"protein_g"`
	Notes           *string `json:"notes"`
}

type checkinOut struct {
	ID              string  `json:"id"`
	CheckinDate     string  `json:"checkin_date"`
	SleepHours      float64 `json:"sleep_hours"`
	EnergyReadiness int     `json:"energy_readiness"`
	CaloriesKcal    int     `json:"calories_kcal"`
	ProteinG        int     `json:"protein_g"`
	Notes           *string `json:"notes,omitempty"`
	CreatedAt       string  `json:"created_at"`
	UpdatedAt       string  `json:"updated_at"`
}

type statusOut struct {
	CheckinDate     string     `json:"checkin_date"`
	HasCheckinToday bool       `json:"has_checkin_today"`
	ShouldPrompt    bool       `json:"should_prompt"`
	Checkin         *checkinOut `json:"checkin"`
}

func toOut(c *Checkin) checkinOut {
	return checkinOut{
		ID:              c.ID,
		CheckinDate:     formatLogicalDate(c.CheckinDate),
		SleepHours:      c.SleepHours,
		EnergyReadiness: c.EnergyReadiness,
		CaloriesKcal:    c.CaloriesKcal,
		ProteinG:        c.ProteinG,
		Notes:           c.Notes,
		CreatedAt:       c.CreatedAt.UTC().Format(time.RFC3339),
		UpdatedAt:       c.UpdatedAt.UTC().Format(time.RFC3339),
	}
}

func (h *Handler) create(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	var body createBody
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	checkinDate := TodayUTC()
	if body.CheckinDate != nil && strings.TrimSpace(*body.CheckinDate) != "" {
		d, err := ParseLogicalDate(*body.CheckinDate)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "checkin_date must be YYYY-MM-DD"})
			return
		}
		checkinDate = d
	}
	if err := validateCheckin(body.SleepHours, body.EnergyReadiness, body.CaloriesKcal, body.ProteinG, body.Notes); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	saved, err := h.repo.Upsert(c.Request.Context(), UpsertInput{
		UserID:          userID,
		CheckinDate:     checkinDate,
		SleepHours:      body.SleepHours,
		EnergyReadiness: body.EnergyReadiness,
		CaloriesKcal:    body.CaloriesKcal,
		ProteinG:        body.ProteinG,
		Notes:           trimNotes(body.Notes),
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	c.JSON(http.StatusCreated, toOut(saved))
}

func (h *Handler) latest(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	row, err := h.repo.GetLatest(c.Request.Context(), userID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "no check-ins yet"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"checkin": toOut(row)})
}

func (h *Handler) status(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	checkinDate, err := resolveCheckinDateQuery(c.Query("checkin_date"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	row, err := h.repo.GetByDate(c.Request.Context(), userID, checkinDate)
	if err != nil && !errors.Is(err, ErrNotFound) {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	has := row != nil
	out := statusOut{
		CheckinDate:     formatLogicalDate(checkinDate),
		HasCheckinToday: has,
		ShouldPrompt:    !has,
	}
	if has {
		ci := toOut(row)
		out.Checkin = &ci
	}
	c.JSON(http.StatusOK, out)
}

func (h *Handler) list(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	fromStr := strings.TrimSpace(c.Query("from"))
	toStr := strings.TrimSpace(c.Query("to"))
	to := TodayUTC()
	from := to.AddDate(0, 0, -29)
	if toStr != "" {
		d, err := ParseLogicalDate(toStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "to must be YYYY-MM-DD"})
			return
		}
		to = d
	}
	if fromStr != "" {
		d, err := ParseLogicalDate(fromStr)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "from must be YYYY-MM-DD"})
			return
		}
		from = d
	}
	if from.After(to) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "from must be on or before to"})
		return
	}
	list, err := h.repo.ListByDateRange(c.Request.Context(), userID, from, to)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	out := make([]checkinOut, 0, len(list))
	for i := range list {
		out = append(out, toOut(&list[i]))
	}
	c.JSON(http.StatusOK, gin.H{"checkins": out})
}

func resolveCheckinDateQuery(raw string) (time.Time, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return TodayUTC(), nil
	}
	d, err := ParseLogicalDate(raw)
	if err != nil {
		return time.Time{}, errors.New("checkin_date must be YYYY-MM-DD")
	}
	return d, nil
}

func validateCheckin(sleepH float64, energy int, cals int, proteinG int, notes *string) error {
	if sleepH < 0 || sleepH > 24 {
		return errors.New("sleep_hours must be between 0 and 24")
	}
	if energy < 1 || energy > 5 {
		return errors.New("energy_readiness must be between 1 and 5")
	}
	if cals < 0 || cals > 20000 {
		return errors.New("calories_kcal must be between 0 and 20000")
	}
	if proteinG < 0 || proteinG > 800 {
		return errors.New("protein_g must be between 0 and 800")
	}
	if notes != nil && utf8.RuneCountInString(*notes) > 2000 {
		return errors.New("notes too long")
	}
	return nil
}

func trimNotes(n *string) *string {
	if n == nil {
		return nil
	}
	s := strings.TrimSpace(*n)
	if s == "" {
		return nil
	}
	return &s
}
