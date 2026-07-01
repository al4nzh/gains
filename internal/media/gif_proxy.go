package media

import (
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

var exerciseGIFIDPattern = regexp.MustCompile(`^[A-Za-z0-9]{4,24}$`)

// GIFProxyConfig configures the public GIF proxy (RapidAPI / AscendAPI).
type GIFProxyConfig struct {
	RapidAPIKey  string
	ImageURL     string // e.g. https://exercisedb.p.rapidapi.com/image
	RapidAPIHost string // e.g. exercisedb.p.rapidapi.com
	Resolution   string // 180, 360, 720, 1080 — tier-dependent
}

// GIFProxy streams ExerciseDB GIFs through the API host (public, no app auth).
// RapidAPI credentials stay server-side only.
type GIFProxy struct {
	cfg    GIFProxyConfig
	client *http.Client
}

func NewGIFProxy(cfg GIFProxyConfig) *GIFProxy {
	cfg.RapidAPIKey = strings.TrimSpace(cfg.RapidAPIKey)
	cfg.ImageURL = strings.TrimSpace(cfg.ImageURL)
	if cfg.ImageURL == "" {
		cfg.ImageURL = "https://exercisedb.p.rapidapi.com/image"
	}
	cfg.RapidAPIHost = strings.TrimSpace(cfg.RapidAPIHost)
	if cfg.RapidAPIHost == "" {
		cfg.RapidAPIHost = "exercisedb.p.rapidapi.com"
	}
	cfg.Resolution = strings.TrimSpace(cfg.Resolution)
	if cfg.Resolution == "" {
		cfg.Resolution = "180"
	}
	return &GIFProxy{
		cfg: cfg,
		client: &http.Client{
			Timeout: 20 * time.Second,
		},
	}
}

func (p *GIFProxy) RegisterRoutes(r *gin.Engine, limiter gin.HandlerFunc) {
	g := r.Group("/media/exercise-gifs")
	if limiter != nil {
		g.Use(limiter)
	}
	g.GET("/:id", p.serve)
}

func (p *GIFProxy) serve(c *gin.Context) {
	if p.cfg.RapidAPIKey == "" {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "gif service not configured"})
		return
	}

	id := strings.TrimSuffix(strings.TrimSpace(c.Param("id")), ".gif")
	if !exerciseGIFIDPattern.MatchString(id) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid gif id"})
		return
	}

	u, err := url.Parse(p.cfg.ImageURL)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	q := u.Query()
	q.Set("exerciseId", id)
	q.Set("resolution", p.cfg.Resolution)
	u.RawQuery = q.Encode()

	req, err := http.NewRequestWithContext(c.Request.Context(), http.MethodGet, u.String(), nil)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	req.Header.Set("X-RapidAPI-Key", p.cfg.RapidAPIKey)
	req.Header.Set("X-RapidAPI-Host", p.cfg.RapidAPIHost)

	resp, err := p.client.Do(req)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": "gif upstream unavailable"})
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		c.JSON(http.StatusBadGateway, gin.H{"error": "gif upstream error"})
		return
	}

	contentType := strings.ToLower(resp.Header.Get("Content-Type"))
	if !strings.HasPrefix(contentType, "image/") {
		c.JSON(http.StatusBadGateway, gin.H{"error": "gif upstream returned non-image"})
		return
	}

	c.Header("Content-Type", resp.Header.Get("Content-Type"))
	c.Header("Cache-Control", "public, max-age=86400")
	c.Status(http.StatusOK)
	_, _ = io.Copy(c.Writer, resp.Body)
}
