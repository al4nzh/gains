package profile

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

func (h *Handler) RegisterRoutes(r *gin.Engine, requireAuth gin.HandlerFunc) {
	g := r.Group("/profile", requireAuth)
	g.GET("", h.get)
	g.PUT("", h.put)
}

type apiProfile struct {
	UserID         string     `json:"user_id"`
	Age            *int       `json:"age,omitempty"`
	HeightCm       *float64   `json:"height_cm,omitempty"`
	WeightKg       *float64   `json:"weight_kg,omitempty"`
	Goal           *string    `json:"goal,omitempty"`
	Experience     *string    `json:"experience,omitempty"`
	PreferredSplit *string    `json:"preferred_split,omitempty"`
	InjuryNotes    *string    `json:"injury_notes,omitempty"`
	UpdatedAt      *time.Time `json:"updated_at,omitempty"`
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
	if err := validateProfile(merged); err != nil {
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
	return &out
}

func validateProfile(p *Profile) error {
	if p.Age != nil {
		if *p.Age < 10 || *p.Age > 120 {
			return errors.New("age must be between 10 and 120")
		}
	}
	if p.HeightCm != nil {
		if *p.HeightCm < 50 || *p.HeightCm > 300 {
			return errors.New("height_cm must be between 50 and 300")
		}
	}
	if p.WeightKg != nil {
		if *p.WeightKg < 20 || *p.WeightKg > 400 {
			return errors.New("weight_kg must be between 20 and 400")
		}
	}
	if p.FitnessGoal != nil {
		if !isAllowedGoal(*p.FitnessGoal) {
			return errors.New("invalid goal: use muscle_gain, strength, fat_loss, or general_fitness")
		}
	}
	if p.TrainingExperience != nil {
		if !isAllowedExperience(*p.TrainingExperience) {
			return errors.New("invalid experience: use beginner, intermediate, or advanced")
		}
	}
	if p.PreferredSplit != nil && utf8.RuneCountInString(*p.PreferredSplit) > 128 {
		return errors.New("preferred_split must be at most 128 characters")
	}
	if p.InjuryNotes != nil && utf8.RuneCountInString(*p.InjuryNotes) > 2000 {
		return errors.New("injury_notes must be at most 2000 characters")
	}
	return nil
}

func isAllowedGoal(g string) bool {
	switch g {
	case GoalMuscleGain, GoalStrength, GoalFatLoss, GoalGeneralFitness:
		return true
	default:
		return false
	}
}

func isAllowedExperience(e string) bool {
	switch e {
	case ExperienceBeginner, ExperienceIntermediate, ExperienceAdvanced:
		return true
	default:
		return false
	}
}

func toAPI(p *Profile) apiProfile {
	out := apiProfile{
		UserID:         p.UserID,
		Age:            p.Age,
		HeightCm:       p.HeightCm,
		WeightKg:       p.WeightKg,
		Goal:           p.FitnessGoal,
		Experience:     p.TrainingExperience,
		PreferredSplit: p.PreferredSplit,
		InjuryNotes:    p.InjuryNotes,
	}
	if !p.UpdatedAt.IsZero() {
		t := p.UpdatedAt
		out.UpdatedAt = &t
	}
	return out
}
