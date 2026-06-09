package profile

import (
	"context"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"gainsai/internal/auth"
	"gainsai/internal/gymarchetype"
	"gainsai/internal/strength"
)

type gymArchetypeProvider interface {
	GymArchetype(ctx context.Context, userID string) (gymarchetype.Response, error)
}

type Handler struct {
	repo       *Repository
	archetypes gymArchetypeProvider
}

func NewHandler(repo *Repository, archetypes gymArchetypeProvider) *Handler {
	return &Handler{repo: repo, archetypes: archetypes}
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
	Gender                *string    `json:"gender,omitempty"`
	Goal                  *string    `json:"goal,omitempty"`
	Experience            *string    `json:"experience,omitempty"`
	PreferredSplit        *string    `json:"preferred_split,omitempty"`
	TrainingDaysPerWeek   *int       `json:"training_days_per_week,omitempty"`
	InjuryNotes           *string    `json:"injury_notes,omitempty"`
	ActivityLevel         *string    `json:"activity_level,omitempty"`
	StrengthElo           *int       `json:"strength_elo,omitempty"`
	StrengthEloRank       *string    `json:"strength_elo_rank,omitempty"`
	StrengthEloChange30d  *int       `json:"strength_elo_change_30d,omitempty"`
	LastStrengthEloUpdate *time.Time `json:"last_strength_elo_update,omitempty"`
	UpdatedAt             *time.Time `json:"updated_at,omitempty"`
	GymArchetype          any        `json:"gym_archetype,omitempty"`
}

// putBody uses API field names from the product spec (goal, experience, etc.).
type putBody struct {
	Age            *int     `json:"age"`
	HeightCm       *float64 `json:"height_cm"`
	WeightKg       *float64 `json:"weight_kg"`
	Gender         *string  `json:"gender"`
	Goal           *string  `json:"goal"`
	Experience     *string  `json:"experience"`
	PreferredSplit      *string  `json:"preferred_split"`
	TrainingDaysPerWeek *int     `json:"training_days_per_week"`
	InjuryNotes         *string  `json:"injury_notes"`
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
	api := toAPI(p)
	if h.archetypes != nil {
		archetype, err := h.archetypes.GymArchetype(c.Request.Context(), userID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
			return
		}
		api.GymArchetype = archetype
	}
	c.JSON(http.StatusOK, api)
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
	if merged.StrengthElo != nil {
		newRank := strength.RankLabelForGender(*merged.StrengthElo, merged.Gender)
		change30d := 0
		if merged.StrengthEloChange30d != nil {
			change30d = *merged.StrengthEloChange30d
		}
		if merged.StrengthEloRank == nil || *merged.StrengthEloRank != newRank {
			_ = h.repo.UpsertStrengthElo(c.Request.Context(), userID, *merged.StrengthElo, newRank, change30d)
		}
	}
	saved, err := h.repo.GetByUserID(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	api := toAPI(saved)
	if h.archetypes != nil {
		archetype, err := h.archetypes.GymArchetype(c.Request.Context(), userID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
			return
		}
		api.GymArchetype = archetype
	}
	c.JSON(http.StatusOK, api)
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
	if b.Gender != nil {
		if strings.TrimSpace(*b.Gender) == "" {
			out.Gender = nil
		} else {
			g := strings.TrimSpace(*b.Gender)
			out.Gender = &g
		}
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
	if b.TrainingDaysPerWeek != nil {
		out.TrainingDaysPerWeek = b.TrainingDaysPerWeek
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
		Gender:                p.Gender,
		Goal:                  p.FitnessGoal,
		Experience:            p.TrainingExperience,
		PreferredSplit:        p.PreferredSplit,
		TrainingDaysPerWeek:   p.TrainingDaysPerWeek,
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
