package profile

import (
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"gainsai/internal/auth"
)

type Handler struct {
	repo *Repository
}

func NewHandler(repo *Repository) *Handler {
	return &Handler{repo: repo}
}

func (h *Handler) RegisterRoutes(r *gin.Engine, requireAuth gin.HandlerFunc, limiter gin.HandlerFunc) {
	g := r.Group("/profile", requireAuth, limiter)
	g.GET("", h.get)
	g.PUT("", h.put)
}

type apiProfile struct {
	UserID                string     `json:"user_id"`
	Age                   *int       `json:"age,omitempty"`
	HeightCm              *float64   `json:"height_cm,omitempty"`
	WeightKg              *float64   `json:"weight_kg,omitempty"`
	Goal                  *string    `json:"goal,omitempty"`
	Experience            *string    `json:"experience,omitempty"`
	PreferredSplit        *string    `json:"preferred_split,omitempty"`
	InjuryNotes           *string    `json:"injury_notes,omitempty"`
	ActivityLevel         *string    `json:"activity_level,omitempty"`
	StrengthElo           *int       `json:"strength_elo,omitempty"`
	StrengthEloRank       *string    `json:"strength_elo_rank,omitempty"`
	StrengthEloChange30d  *int       `json:"strength_elo_change_30d,omitempty"`
	LastStrengthEloUpdate *time.Time `json:"last_strength_elo_update,omitempty"`
	UpdatedAt             *time.Time `json:"updated_at,omitempty"`
}

// putBody uses API field names from the product spec (goal, experience, etc.).
type putBody struct {
	Age            *int     `json:"age"`
	HeightCm       *float64 `json:"height_cm"`
	WeightKg       *float64 `json:"weight_kg"`
	Goal           *string  `json:"goal"`
	Experience     *string  `json:"experience"`
	PreferredSplit *string  `json:"preferred_split"`
	InjuryNotes    *string  `json:"injury_notes"`
	ActivityLevel  *string  `json:"activity_level"`
}

func (h *Handler) get(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	p, err := h.repo.GetByUserID(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	c.JSON(http.StatusOK, toAPI(p))
}

func (h *Handler) put(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	var body putBody
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	existing, err := h.repo.GetByUserID(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	merged := mergePut(existing, &body)
	if err := Validate(merged); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if err := h.repo.Upsert(c.Request.Context(), merged); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	saved, err := h.repo.GetByUserID(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	c.JSON(http.StatusOK, toAPI(saved))
}

func mergePut(cur *Profile, b *putBody) *Profile {
	out := *cur
	if b.Age != nil {
		out.Age = b.Age
	}
	if b.HeightCm != nil {
		out.HeightCm = b.HeightCm
	}
	if b.WeightKg != nil {
		out.WeightKg = b.WeightKg
	}
	if b.Goal != nil {
		if strings.TrimSpace(*b.Goal) == "" {
			out.FitnessGoal = nil
		} else {
			g := strings.TrimSpace(*b.Goal)
			out.FitnessGoal = &g
		}
	}
	if b.Experience != nil {
		if strings.TrimSpace(*b.Experience) == "" {
			out.TrainingExperience = nil
		} else {
			e := strings.TrimSpace(*b.Experience)
			out.TrainingExperience = &e
		}
	}
	if b.PreferredSplit != nil {
		if strings.TrimSpace(*b.PreferredSplit) == "" {
			out.PreferredSplit = nil
		} else {
			s := strings.TrimSpace(*b.PreferredSplit)
			out.PreferredSplit = &s
		}
	}
	if b.InjuryNotes != nil {
		if strings.TrimSpace(*b.InjuryNotes) == "" {
			out.InjuryNotes = nil
		} else {
			n := strings.TrimSpace(*b.InjuryNotes)
			out.InjuryNotes = &n
		}
	}
	if b.ActivityLevel != nil {
		if strings.TrimSpace(*b.ActivityLevel) == "" {
			out.ActivityLevel = nil
		} else {
			a := strings.TrimSpace(*b.ActivityLevel)
			out.ActivityLevel = &a
		}
	}
	return &out
}

func toAPI(p *Profile) apiProfile {
	out := apiProfile{
		UserID:                p.UserID,
		Age:                   p.Age,
		HeightCm:              p.HeightCm,
		WeightKg:              p.WeightKg,
		Goal:                  p.FitnessGoal,
		Experience:            p.TrainingExperience,
		PreferredSplit:        p.PreferredSplit,
		InjuryNotes:           p.InjuryNotes,
		ActivityLevel:         p.ActivityLevel,
		StrengthElo:           p.StrengthElo,
		StrengthEloRank:       p.StrengthEloRank,
		StrengthEloChange30d:  p.StrengthEloChange30d,
		LastStrengthEloUpdate: p.LastStrengthEloUpdate,
	}
	if !p.UpdatedAt.IsZero() {
		t := p.UpdatedAt
		out.UpdatedAt = &t
	}
	return out
}
