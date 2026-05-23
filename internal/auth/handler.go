package auth

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"

	"gainsai/internal/user"
)

type Handler struct {
	service *Service
	users   *user.Repository
}

func NewHandler(service *Service, users *user.Repository) *Handler {
	return &Handler{service: service, users: users}
}

// RegisterRoutes wires the auth endpoints. authLimiter is applied to /auth/*
// only; RequireAuth is applied to /me.
func (h *Handler) RegisterRoutes(r *gin.Engine, authLimiter, requireAuth gin.HandlerFunc) {
	authGroup := r.Group("/auth")
	authGroup.Use(authLimiter)
	authGroup.POST("/register", h.register)
	authGroup.POST("/login", h.login)
	authGroup.POST("/google", h.googleLogin)
	authGroup.POST("/apple", h.appleLogin)
	authGroup.POST("/refresh", h.refresh)

	r.GET("/me", requireAuth, h.me)
}

type registerReq struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=8"`
}

type loginReq struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

type refreshReq struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

type oauthTokenReq struct {
	IDToken string  `json:"id_token" binding:"required"`
	Email   *string `json:"email,omitempty"` // Apple: client may send email on first authorization only
}

type authResponse struct {
	User   *user.User `json:"user"`
	Tokens *TokenPair `json:"tokens"`
}

func (h *Handler) register(c *gin.Context) {
	var req registerReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	info := ClientInfo{UserAgent: c.GetHeader("User-Agent"), IPAddress: c.ClientIP()}
	u, tokens, err := h.service.Register(c.Request.Context(), req.Email, req.Password, info)
	if err != nil {
		switch {
		case errors.Is(err, user.ErrEmailExists):
			c.JSON(http.StatusConflict, gin.H{"error": "email already registered"})
		case errors.Is(err, ErrWeakPassword):
			c.JSON(http.StatusBadRequest, gin.H{"error": "password too weak"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		}
		return
	}
	c.JSON(http.StatusCreated, authResponse{User: u, Tokens: tokens})
}

func (h *Handler) login(c *gin.Context) {
	var req loginReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	info := ClientInfo{UserAgent: c.GetHeader("User-Agent"), IPAddress: c.ClientIP()}
	u, tokens, err := h.service.Login(c.Request.Context(), req.Email, req.Password, info)
	if err != nil {
		if errors.Is(err, ErrInvalidCredentials) {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid email or password"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	c.JSON(http.StatusOK, authResponse{User: u, Tokens: tokens})
}

func (h *Handler) googleLogin(c *gin.Context) {
	var req oauthTokenReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	info := ClientInfo{UserAgent: c.GetHeader("User-Agent"), IPAddress: c.ClientIP()}
	u, tokens, err := h.service.LoginGoogle(c.Request.Context(), req.IDToken, info)
	writeOAuthResponse(c, u, tokens, err)
}

func (h *Handler) appleLogin(c *gin.Context) {
	var req oauthTokenReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	info := ClientInfo{UserAgent: c.GetHeader("User-Agent"), IPAddress: c.ClientIP()}
	email := ""
	if req.Email != nil {
		email = *req.Email
	}
	u, tokens, err := h.service.LoginApple(c.Request.Context(), req.IDToken, email, info)
	writeOAuthResponse(c, u, tokens, err)
}

func writeOAuthResponse(c *gin.Context, u *user.User, tokens *TokenPair, err error) {
	if err != nil {
		switch {
		case errors.Is(err, ErrOAuthNotConfigured):
			c.JSON(http.StatusServiceUnavailable, gin.H{"error": "google/apple sign-in is not configured on the server"})
		case errors.Is(err, ErrInvalidOAuthToken):
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid or expired sign-in token"})
		case errors.Is(err, ErrOAuthEmailConflict):
			c.JSON(http.StatusConflict, gin.H{"error": "email already registered with email and password — sign in with email or use a different account"})
		case errors.Is(err, ErrOAuthEmailRequired):
			c.JSON(http.StatusBadRequest, gin.H{"error": "email required on first Apple sign-in — pass email from the Apple authorization response"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		}
		return
	}
	c.JSON(http.StatusOK, authResponse{User: u, Tokens: tokens})
}

func (h *Handler) refresh(c *gin.Context) {
	var req refreshReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	info := ClientInfo{UserAgent: c.GetHeader("User-Agent"), IPAddress: c.ClientIP()}
	tokens, err := h.service.Refresh(c.Request.Context(), req.RefreshToken, info)
	if err != nil {
		switch {
		case errors.Is(err, ErrRefreshNotFound),
			errors.Is(err, ErrRefreshExpired),
			errors.Is(err, ErrRefreshRevoked):
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid refresh token"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		}
		return
	}
	c.JSON(http.StatusOK, gin.H{"tokens": tokens})
}

func (h *Handler) me(c *gin.Context) {
	userID, ok := UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	u, err := h.users.GetByID(c.Request.Context(), userID)
	if err != nil {
		if errors.Is(err, user.ErrNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	c.JSON(http.StatusOK, u)
}
