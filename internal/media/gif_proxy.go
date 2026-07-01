package media

import (
	"encoding/json"
	"fmt"
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
	APIHost      string // edb-with-gifs-and-images-by-ascendapi.p.rapidapi.com
	ImageURL     string // optional legacy stream URL
	Resolution   string // 180, 360, …
}

// GIFProxy streams ExerciseDB GIFs through the API host (public, no app auth).
type GIFProxy struct {
	cfg    GIFProxyConfig
	client *http.Client
}

func NewGIFProxy(cfg GIFProxyConfig) *GIFProxy {
	cfg.RapidAPIKey = strings.TrimSpace(cfg.RapidAPIKey)
	cfg.APIHost = strings.TrimSpace(cfg.APIHost)
	if cfg.APIHost == "" {
		cfg.APIHost = "edb-with-gifs-and-images-by-ascendapi.p.rapidapi.com"
	}
	cfg.ImageURL = strings.TrimSpace(cfg.ImageURL)
	if cfg.ImageURL == "" {
		// OSS media ids (e.g. EIeI8Vf) work on the legacy image stream, not /api/v1/exercises/{edb_...}.
		cfg.ImageURL = "https://exercisedb.p.rapidapi.com/image"
	}
	cfg.Resolution = strings.TrimSpace(cfg.Resolution)
	if cfg.Resolution == "" {
		cfg.Resolution = "180"
	}
	return &GIFProxy{
		cfg: cfg,
		client: &http.Client{
			Timeout: 25 * time.Second,
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

	body, contentType, err := p.fetchGIF(c, id)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": err.Error()})
		return
	}
	defer body.Close()

	c.Header("Content-Type", contentType)
	// AscendAPI allows short operational cache only (≤1h).
	c.Header("Cache-Control", "public, max-age=3600")
	c.Status(http.StatusOK)
	_, _ = io.Copy(c.Writer, body)
}

func (p *GIFProxy) fetchGIF(c *gin.Context, exerciseID string) (io.ReadCloser, string, error) {
	// 1) Image stream — accepts OSS media ids (EIeI8Vf) used by our catalog.
	if body, ct, err := p.fetchImageStream(c, exerciseID); err == nil {
		return body, ct, nil
	}

	// 2) V1 JSON metadata — uses edb_* ids on the paid API (fallback).
	return p.fetchViaExerciseMetadata(c, exerciseID)
}

func (p *GIFProxy) fetchImageStream(c *gin.Context, exerciseID string) (io.ReadCloser, string, error) {
	u, err := url.Parse(p.cfg.ImageURL)
	if err != nil {
		return nil, "", err
	}
	q := u.Query()
	q.Set("exerciseId", exerciseID)
	q.Set("resolution", p.cfg.Resolution)
	u.RawQuery = q.Encode()

	host := "exercisedb.p.rapidapi.com"
	if strings.Contains(u.Host, "edb-with-gifs-and-images") {
		host = p.cfg.APIHost
	}

	return p.doGET(c, u.String(), host)
}

func (p *GIFProxy) fetchViaExerciseMetadata(c *gin.Context, exerciseID string) (io.ReadCloser, string, error) {
	metaURL := fmt.Sprintf("https://%s/api/v1/exercises/%s", p.cfg.APIHost, url.PathEscape(exerciseID))
	body, _, err := p.doGETBytes(c, metaURL, p.cfg.APIHost)
	if err != nil {
		return nil, "", fmt.Errorf("rapidapi metadata: %w", err)
	}

	var parsed struct {
		Success bool `json:"success"`
		Data    struct {
			GifURL  string            `json:"gifUrl"`
			GifURLs map[string]string `json:"gifUrls"`
		} `json:"data"`
	}
	if err := json.Unmarshal(body, &parsed); err != nil {
		return nil, "", fmt.Errorf("rapidapi metadata parse failed")
	}
	if !parsed.Success {
		return nil, "", fmt.Errorf("rapidapi metadata: exercise not found")
	}

	gifURL := pickGIFURL(parsed.Data.GifURLs, parsed.Data.GifURL, p.cfg.Resolution)
	if gifURL == "" {
		return nil, "", fmt.Errorf("rapidapi metadata: no gif url for exercise")
	}
	gifURL = normalizeAssetGIFURL(gifURL)

	return p.doGET(c, gifURL, "")
}

func pickGIFURL(urls map[string]string, fallback, resolution string) string {
	if len(urls) > 0 {
		for _, key := range []string{resolution + "p", resolution, "180p", "360p", "480p", "720p", "1080p"} {
			if u := strings.TrimSpace(urls[key]); u != "" {
				return u
			}
		}
		for _, u := range urls {
			if u = strings.TrimSpace(u); u != "" {
				return u
			}
		}
	}
	return strings.TrimSpace(fallback)
}

func normalizeAssetGIFURL(raw string) string {
	raw = strings.TrimSpace(raw)
	raw = strings.Replace(raw, "https://static.exercisedb.dev/media/", "https://assets.exercisedb.dev/media/", 1)
	return raw
}

func (p *GIFProxy) doGET(c *gin.Context, rawURL, rapidHost string) (io.ReadCloser, string, error) {
	body, ct, err := p.doGETBytes(c, rawURL, rapidHost)
	if err != nil {
		return nil, "", err
	}
	return io.NopCloser(strings.NewReader(string(body))), ct, nil
}

func (p *GIFProxy) doGETBytes(c *gin.Context, rawURL, rapidHost string) ([]byte, string, error) {
	req, err := http.NewRequestWithContext(c.Request.Context(), http.MethodGet, rawURL, nil)
	if err != nil {
		return nil, "", err
	}
	if rapidHost != "" {
		req.Header.Set("X-RapidAPI-Key", p.cfg.RapidAPIKey)
		req.Header.Set("X-RapidAPI-Host", rapidHost)
	} else {
		req.Header.Set("User-Agent", "GainsAPI/1.0")
	}

	resp, err := p.client.Do(req)
	if err != nil {
		return nil, "", fmt.Errorf("upstream unavailable: %v", err)
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if err != nil {
		return nil, "", err
	}
	if resp.StatusCode != http.StatusOK {
		snippet := strings.TrimSpace(string(data))
		if len(snippet) > 120 {
			snippet = snippet[:120]
		}
		return nil, "", fmt.Errorf("upstream HTTP %d: %s", resp.StatusCode, snippet)
	}

	ct := strings.ToLower(resp.Header.Get("Content-Type"))
	if rapidHost != "" && strings.Contains(ct, "json") {
		// Metadata call — caller parses JSON.
		return data, resp.Header.Get("Content-Type"), nil
	}
	if !strings.HasPrefix(ct, "image/") {
		return nil, "", fmt.Errorf("upstream returned non-image (%s)", ct)
	}
	return data, resp.Header.Get("Content-Type"), nil
}
