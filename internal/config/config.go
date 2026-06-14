package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/joho/godotenv"
)

type Config struct {
	Env         string
	Port        string
	DatabaseURL string

	JWTSecret     string
	JWTAccessTTL  time.Duration
	JWTRefreshTTL time.Duration

	GoogleOAuthClientIDs []string
	AppleOAuthClientID   string

	AuthRateLimitRPS   float64
	AuthRateLimitBurst int

	ProfileRateLimitRPS   float64
	ProfileRateLimitBurst int

	ExerciseRateLimitRPS   float64
	ExerciseRateLimitBurst int

	RoutineRateLimitRPS   float64
	RoutineRateLimitBurst int

	WorkoutRateLimitRPS   float64
	WorkoutRateLimitBurst int

	RecoveryRateLimitRPS   float64
	RecoveryRateLimitBurst int

	AnalyticsRateLimitRPS   float64
	AnalyticsRateLimitBurst int

	OpenAIAPIKey     string
	OpenAIModel      string
	AIRateLimitRPS   float64
	AIRateLimitBurst int

	AIRequirePremium          bool
	AIDailyCoachMessages      int
	AIDailyWorkoutAnalyses    int
	AIDailyRoutineGenerations int
	AIDailyPhysiqueScans      int

	PhysiqueScanModel      string
	PhysiqueRateLimitRPS   float64
	PhysiqueRateLimitBurst int

	ExerciseDBEnabled bool
	ExerciseDBBaseURL string

	SMTPHost         string
	SMTPPort         string
	SMTPUser         string
	SMTPPass         string
	ResendAPIKey     string
	EmailFrom        string
	AppName          string

	RevenueCatWebhookSecret   string
	RevenueCatSecretAPIKey    string
	RevenueCatEntitlementID   string
}

func Load() (*Config, error) {
	_ = godotenv.Load()

	cfg := &Config{
		Env:         getEnv("ENV", "development"),
		Port:        getEnv("PORT", "8080"),
		DatabaseURL: os.Getenv("DATABASE_URL"),
		JWTSecret:   os.Getenv("JWT_SECRET"),
	}

	if cfg.DatabaseURL == "" {
		return nil, fmt.Errorf("DATABASE_URL is required")
	}
	if cfg.JWTSecret == "" {
		return nil, fmt.Errorf("JWT_SECRET is required")
	}
	if len(cfg.JWTSecret) < 32 {
		return nil, fmt.Errorf("JWT_SECRET must be at least 32 bytes")
	}

	var err error
	if cfg.JWTAccessTTL, err = parseDuration("JWT_ACCESS_TTL", "15m"); err != nil {
		return nil, err
	}
	if cfg.JWTRefreshTTL, err = parseDuration("JWT_REFRESH_TTL", "720h"); err != nil {
		return nil, err
	}

	cfg.GoogleOAuthClientIDs = parseCSVEnv("GOOGLE_OAUTH_CLIENT_IDS")
	cfg.AppleOAuthClientID = strings.TrimSpace(os.Getenv("APPLE_OAUTH_CLIENT_ID"))

	cfg.AuthRateLimitRPS = parseFloat("AUTH_RATE_LIMIT_RPS", 5)
	cfg.AuthRateLimitBurst = parseInt("AUTH_RATE_LIMIT_BURST", 10)

	cfg.ProfileRateLimitRPS = parseFloat("PROFILE_RATE_LIMIT_RPS", 10)
	cfg.ProfileRateLimitBurst = parseInt("PROFILE_RATE_LIMIT_BURST", 20)

	cfg.ExerciseRateLimitRPS = parseFloat("EXERCISE_RATE_LIMIT_RPS", 20)
	cfg.ExerciseRateLimitBurst = parseInt("EXERCISE_RATE_LIMIT_BURST", 40)

	cfg.RoutineRateLimitRPS = parseFloat("ROUTINE_RATE_LIMIT_RPS", 15)
	cfg.RoutineRateLimitBurst = parseInt("ROUTINE_RATE_LIMIT_BURST", 30)

	cfg.WorkoutRateLimitRPS = parseFloat("WORKOUT_RATE_LIMIT_RPS", 25)
	cfg.WorkoutRateLimitBurst = parseInt("WORKOUT_RATE_LIMIT_BURST", 50)

	cfg.RecoveryRateLimitRPS = parseFloat("RECOVERY_RATE_LIMIT_RPS", 15)
	cfg.RecoveryRateLimitBurst = parseInt("RECOVERY_RATE_LIMIT_BURST", 30)

	cfg.AnalyticsRateLimitRPS = parseFloat("ANALYTICS_RATE_LIMIT_RPS", 10)
	cfg.AnalyticsRateLimitBurst = parseInt("ANALYTICS_RATE_LIMIT_BURST", 20)

	cfg.OpenAIAPIKey = strings.TrimSpace(os.Getenv("OPENAI_API_KEY"))
	cfg.OpenAIModel = getEnv("OPENAI_MODEL", "gpt-4o-mini")
	cfg.AIRateLimitRPS = parseFloat("AI_RATE_LIMIT_RPS", 3)
	cfg.AIRateLimitBurst = parseInt("AI_RATE_LIMIT_BURST", 6)

	cfg.AIRequirePremium = parseBool("AI_REQUIRE_PREMIUM", false)
	cfg.AIDailyCoachMessages = parseInt("AI_DAILY_COACH_MESSAGES", 200)
	cfg.AIDailyWorkoutAnalyses = parseInt("AI_DAILY_WORKOUT_ANALYSES", 50)
	cfg.AIDailyRoutineGenerations = parseInt("AI_DAILY_ROUTINE_GENS", 30)
	cfg.AIDailyPhysiqueScans = parseInt("AI_DAILY_PHYSIQUE_SCANS", 20)

	cfg.PhysiqueScanModel = getEnv("PHYSIQUE_SCAN_MODEL", "gpt-5.4-mini")
	cfg.PhysiqueRateLimitRPS = parseFloat("PHYSIQUE_RATE_LIMIT_RPS", 2)
	cfg.PhysiqueRateLimitBurst = parseInt("PHYSIQUE_RATE_LIMIT_BURST", 4)

	cfg.ExerciseDBEnabled = parseBool("EXERCISEDB_ENABLED", true)
	cfg.ExerciseDBBaseURL = getEnv("EXERCISEDB_BASE_URL", "https://oss.exercisedb.dev/api/v1")

	cfg.SMTPHost = strings.TrimSpace(os.Getenv("SMTP_HOST"))
	cfg.SMTPPort = getEnv("SMTP_PORT", "587")
	cfg.SMTPUser = strings.TrimSpace(os.Getenv("SMTP_USER"))
	cfg.SMTPPass = os.Getenv("SMTP_PASS")
	cfg.ResendAPIKey = strings.TrimSpace(os.Getenv("RESEND_API_KEY"))
	cfg.EmailFrom = strings.TrimSpace(os.Getenv("EMAIL_FROM"))
	cfg.AppName = getEnv("APP_NAME", "Gains")

	cfg.RevenueCatWebhookSecret = strings.TrimSpace(os.Getenv("REVENUECAT_WEBHOOK_SECRET"))
	cfg.RevenueCatSecretAPIKey = strings.TrimSpace(os.Getenv("REVENUECAT_SECRET_API_KEY"))
	cfg.RevenueCatEntitlementID = getEnv("REVENUECAT_ENTITLEMENT_ID", "premium")

	if err := cfg.validate(); err != nil {
		return nil, err
	}

	return cfg, nil
}

func (c *Config) validate() error {
	if !c.IsProduction() {
		return nil
	}
	if c.EmailFrom == "" {
		return fmt.Errorf("EMAIL_FROM is required when ENV=production (e.g. Gains <noreply@yourdomain.com>)")
	}
	if c.ResendAPIKey == "" && c.SMTPHost == "" {
		return fmt.Errorf("RESEND_API_KEY or SMTP_HOST is required when ENV=production")
	}
	return nil
}

func (c *Config) IsProduction() bool {
	return c.Env == "production"
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func parseDuration(key, fallback string) (time.Duration, error) {
	v := getEnv(key, fallback)
	d, err := time.ParseDuration(v)
	if err != nil {
		return 0, fmt.Errorf("invalid %s: %w", key, err)
	}
	return d, nil
}

func parseFloat(key string, fallback float64) float64 {
	if v := os.Getenv(key); v != "" {
		if f, err := strconv.ParseFloat(v, 64); err == nil {
			return f
		}
	}
	return fallback
}

func parseInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if i, err := strconv.Atoi(v); err == nil {
			return i
		}
	}
	return fallback
}

func parseBool(key string, fallback bool) bool {
	v := strings.TrimSpace(strings.ToLower(os.Getenv(key)))
	if v == "" {
		return fallback
	}
	switch v {
	case "1", "true", "yes", "on":
		return true
	case "0", "false", "no", "off":
		return false
	default:
		return fallback
	}
}

func parseCSVEnv(key string) []string {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return nil
	}
	parts := strings.Split(raw, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}
