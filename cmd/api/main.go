package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"

	"gainsai/internal/adaptiverecommendations"
	"gainsai/internal/ai"
	"gainsai/internal/aiquota"
	"gainsai/internal/analytics"
	"gainsai/internal/auth"
	"gainsai/internal/config"
	"gainsai/internal/db"
	"gainsai/internal/email"
	"gainsai/internal/exercise"
	"gainsai/internal/exercisedb"
	"gainsai/internal/middleware"
	"gainsai/internal/physique"
	"gainsai/internal/profile"
	"gainsai/internal/recovery"
	"gainsai/internal/routine"
	"gainsai/internal/user"
	"gainsai/internal/workout"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("config: %v", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	pool, err := db.New(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("db: %v", err)
	}
	defer pool.Close()
	log.Println("connected to postgres")

	if cfg.IsProduction() {
		gin.SetMode(gin.ReleaseMode)
	}

	userRepo := user.NewRepository(pool)
	refreshStore := auth.NewRefreshStore(pool)
	emailTokenStore := auth.NewEmailTokenStore(pool)
	mailer := email.NewMailer(email.Config{
		From:         cfg.EmailFrom,
		ResendAPIKey: cfg.ResendAPIKey,
		SMTPHost:     cfg.SMTPHost,
		SMTPPort:     cfg.SMTPPort,
		SMTPUser:     cfg.SMTPUser,
		SMTPPass:     cfg.SMTPPass,
		AppName:      cfg.AppName,
		Production:   cfg.IsProduction(),
	})
	jwtIssuer := auth.NewJWTIssuer(cfg.JWTSecret, cfg.JWTAccessTTL)
	authService := auth.NewService(userRepo, refreshStore, emailTokenStore, mailer, jwtIssuer, cfg.JWTRefreshTTL, cfg.GoogleOAuthClientIDs, cfg.AppleOAuthClientID, cfg.AppName)
	authHandler := auth.NewHandler(authService, userRepo)

	authLimiter := middleware.NewIPRateLimiter(cfg.AuthRateLimitRPS, cfg.AuthRateLimitBurst)
	profileLimiter := middleware.NewIPRateLimiter(cfg.ProfileRateLimitRPS, cfg.ProfileRateLimitBurst)
	exerciseLimiter := middleware.NewIPRateLimiter(cfg.ExerciseRateLimitRPS, cfg.ExerciseRateLimitBurst)
	routineLimiter := middleware.NewIPRateLimiter(cfg.RoutineRateLimitRPS, cfg.RoutineRateLimitBurst)
	workoutLimiter := middleware.NewIPRateLimiter(cfg.WorkoutRateLimitRPS, cfg.WorkoutRateLimitBurst)
	recoveryLimiter := middleware.NewIPRateLimiter(cfg.RecoveryRateLimitRPS, cfg.RecoveryRateLimitBurst)
	analyticsLimiter := middleware.NewIPRateLimiter(cfg.AnalyticsRateLimitRPS, cfg.AnalyticsRateLimitBurst)

	r := gin.New()
	r.Use(gin.Recovery(), gin.Logger(), middleware.RequestID())
	// Configure trusted proxies properly when deploying behind a load balancer.
	_ = r.SetTrustedProxies(nil)

	r.GET("/health", func(c *gin.Context) {
		pingCtx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Second)
		defer cancel()
		if err := pool.Ping(pingCtx); err != nil {
			if cfg.IsProduction() {
				c.JSON(http.StatusServiceUnavailable, gin.H{"status": "unhealthy"})
			} else {
				c.JSON(http.StatusServiceUnavailable, gin.H{
					"status": "unhealthy",
					"db":     "down",
					"error":  err.Error(),
				})
			}
			return
		}
		c.JSON(http.StatusOK, gin.H{"status": "ok", "db": "up"})
	})

	requireAuth := auth.RequireAuth(jwtIssuer)
	requireVerifiedEmail := auth.RequireVerifiedEmail(userRepo)
	requireAppAccess := func(c *gin.Context) {
		requireAuth(c)
		if c.IsAborted() {
			return
		}
		requireVerifiedEmail(c)
	}
	authHandler.RegisterRoutes(r, authLimiter.Middleware(), requireAuth)

	profileRepo := profile.NewRepository(pool)
	profileHandler := profile.NewHandler(profileRepo)
	profileHandler.RegisterRoutes(r, requireAppAccess, profileLimiter.Middleware())

	exerciseRepo := exercise.NewRepository(pool)
	exerciseDBClient := exercisedb.NewClient(cfg.ExerciseDBBaseURL)
	exerciseDBGifSvc := exercisedb.NewService(exerciseDBClient, cfg.ExerciseDBEnabled)
	exerciseHandler := exercise.NewHandler(exerciseRepo, exerciseDBGifSvc)
	exerciseHandler.RegisterRoutes(r, requireAppAccess, exerciseLimiter.Middleware())

	routineRepo := routine.NewRepository(pool)
	routineSvc := routine.NewService(routineRepo)
	routineHandler := routine.NewHandler(routineSvc)
	routineHandler.RegisterRoutes(r, requireAppAccess, routineLimiter.Middleware())

	workoutRepo := workout.NewRepository(pool)
	workoutSvc := workout.NewService(pool, workoutRepo, profileRepo, exerciseRepo)
	workoutHandler := workout.NewHandler(workoutSvc)
	workoutHandler.RegisterRoutes(r, requireAppAccess, workoutLimiter.Middleware())

	recoveryRepo := recovery.NewRepository(pool)
	recoveryHandler := recovery.NewHandler(recoveryRepo)
	recoveryHandler.RegisterRoutes(r, requireAppAccess, recoveryLimiter.Middleware())

	aiRepo := ai.NewRepository(pool)
	analyticsRepo := analytics.NewRepository(pool)

	adaptiveRepo := adaptiverecommendations.NewRepository(pool)
	adaptiveSvc := adaptiverecommendations.NewService(
		adaptiveRepo, routineRepo, workoutRepo, recoveryRepo, profileRepo, analyticsRepo, exerciseRepo,
	)
	adaptiveHandler := adaptiverecommendations.NewHandler(adaptiveSvc)
	adaptiveHandler.RegisterRoutes(r, requireAppAccess, workoutLimiter.Middleware())
	analyticsSvc := analytics.NewService(analyticsRepo, recoveryRepo, profileRepo, routineRepo, workoutRepo, aiRepo)
	analyticsHandler := analytics.NewHandler(analyticsSvc)
	analyticsHandler.RegisterRoutes(r, requireAppAccess, analyticsLimiter.Middleware())

	aiLimiter := middleware.NewIPRateLimiter(cfg.AIRateLimitRPS, cfg.AIRateLimitBurst)
	aiQuotaRepo := aiquota.NewRepository(pool)
	aiQuotaSvc := aiquota.NewService(aiQuotaRepo, userRepo, cfg)
	chatRepo := ai.NewChatRepository(pool)
	actionRepo := ai.NewActionRepository(pool)
	routineDraftRepo := ai.NewRoutineDraftRepository(pool)
	aiSvc := ai.NewService(aiRepo, chatRepo, actionRepo, routineDraftRepo, workoutRepo, profileRepo, routineRepo, routineSvc, exerciseRepo, cfg, analyticsSvc, aiQuotaSvc)
	aiHandler := ai.NewHandler(aiSvc)
	aiHandler.RegisterRoutes(r, requireAppAccess, aiLimiter.Middleware())

	physiqueLimiter := middleware.NewIPRateLimiter(cfg.PhysiqueRateLimitRPS, cfg.PhysiqueRateLimitBurst)
	physiqueRepo := physique.NewRepository(pool)
	physiqueSvc := physique.NewService(physiqueRepo, cfg, aiQuotaSvc)
	physiqueHandler := physique.NewHandler(physiqueSvc)
	physiqueHandler.RegisterRoutes(r, requireAppAccess, physiqueLimiter.Middleware())

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           r,
		ReadHeaderTimeout: 10 * time.Second,
	}

	go func() {
		log.Printf("server listening on :%s (env=%s)", cfg.Port, cfg.Env)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("server: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("shutting down...")

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownCancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Fatalf("forced shutdown: %v", err)
	}
	log.Println("server stopped")
}
