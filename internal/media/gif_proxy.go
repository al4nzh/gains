package media

import (
	"io"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

var exerciseGIFIDPattern = regexp.MustCompile(`^[A-Za-z0-9]{4,24}$`)

// GIFProxy streams ExerciseDB GIFs through the API host (public, no auth).
type GIFProxy struct {
	upstreamBase string
	client       *http.Client
}

func NewGIFProxy(upstreamBase string) *GIFProxy {
	upstreamBase = strings.TrimRight(strings.TrimSpace(upstreamBase), "/")
	if upstreamBase == "" {
		upstreamBase = "https://exercisedb.dev/media"
	}
	return &GIFProxy{
		upstreamBase: upstreamBase,
		client: &http.Client{
			Timeout: 15 * time.Second,
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
	id := strings.TrimSuffix(strings.TrimSpace(c.Param("id")), ".gif")
	if !exerciseGIFIDPattern.MatchString(id) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid gif id"})
		return
	}

	upstream := p.upstreamBase + "/" + id + ".gif"
	req, err := http.NewRequestWithContext(c.Request.Context(), http.MethodGet, upstream, nil)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	req.Header.Set("User-Agent", "GainsAPI/1.0")

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

	contentType := resp.Header.Get("Content-Type")
	if contentType == "" {
		contentType = "image/gif"
	}
	c.Header("Content-Type", contentType)
	c.Header("Cache-Control", "public, max-age=86400")
	c.Status(http.StatusOK)
	_, _ = io.Copy(c.Writer, resp.Body)
}
