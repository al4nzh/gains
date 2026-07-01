package media

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"gainsai/internal/exercisedb"
)

var exerciseGIFIDPattern = regexp.MustCompile(`^[A-Za-z0-9]{4,24}$`)

// GIFProxyConfig configures the public GIF proxy (RapidAPI / AscendAPI).
type GIFProxyConfig struct {
	RapidAPIKey string
	APIHost     string // edb-with-gifs-and-images-by-ascendapi.p.rapidapi.com
	Resolution  string // 180, 360, …
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
	c.Header("Cache-Control", "public, max-age=3600")
	c.Status(http.StatusOK)
	_, _ = io.Copy(c.Writer, body)
}

func (p *GIFProxy) fetchGIF(c *gin.Context, mediaID string) (io.ReadCloser, string, error) {
	var errs []string
	record := func(err error) {
		if err != nil {
			errs = append(errs, err.Error())
		}
	}

	// Legacy OSS media id stream (often 403 unless subscribed to exercisedb.p.rapidapi.com).
	if body, ct, err := p.fetchImageStream(c, "https://exercisedb.p.rapidapi.com/image", "exercisedb.p.rapidapi.com", mediaID); err == nil {
		return body, ct, nil
	} else {
		record(err)
	}

	catalogName := exercisedb.CatalogSearchNameForMediaID(mediaID)
	if catalogName == "" {
		return nil, "", fmt.Errorf("%s", strings.Join(errs, "; "))
	}

	edbID, err := p.lookupPaidExerciseID(c, catalogName)
	if err != nil {
		record(err)
		return nil, "", fmt.Errorf("%s", strings.Join(errs, "; "))
	}

	// Paid exercise id image stream.
	if body, ct, err := p.fetchImageStream(c, "https://exercisedb.p.rapidapi.com/image", "exercisedb.p.rapidapi.com", edbID); err == nil {
		return body, ct, nil
	} else {
		record(err)
	}
	if body, ct, err := p.fetchImageStream(c, fmt.Sprintf("https://%s/image", p.cfg.APIHost), p.cfg.APIHost, edbID); err == nil {
		return body, ct, nil
	} else {
		record(err)
	}

	// Metadata + asset CDN URL from paid API.
	if body, ct, err := p.fetchViaExerciseMetadata(c, edbID); err == nil {
		return body, ct, nil
	} else {
		record(err)
	}

	return nil, "", fmt.Errorf("%s", strings.Join(errs, "; "))
}

type rapidExercise struct {
	ExerciseID string `json:"exerciseId"`
	Name       string `json:"name"`
	GifURL     string `json:"gifUrl"`
	GifURLs    map[string]string `json:"gifUrls"`
}

func (p *GIFProxy) lookupPaidExerciseID(c *gin.Context, catalogName string) (string, error) {
	// AscendAPI V1 filter: GET /api/v1/exercises?name=Bench+Press&limit=10
	u := url.URL{
		Scheme: "https",
		Host:   p.cfg.APIHost,
		Path:   "/api/v1/exercises",
	}
	q := u.Query()
	q.Set("name", catalogName)
	q.Set("limit", "10")
	u.RawQuery = q.Encode()

	body, _, err := p.doRapidAPIJSON(c, u.String(), p.cfg.APIHost)
	if err != nil {
		return "", fmt.Errorf("rapidapi filter: %w", err)
	}

	var parsed struct {
		Success bool            `json:"success"`
		Data    []rapidExercise `json:"data"`
	}
	if err := json.Unmarshal(body, &parsed); err != nil {
		return "", fmt.Errorf("rapidapi filter parse failed")
	}
	if !parsed.Success || len(parsed.Data) == 0 {
		// Fallback: fuzzy search endpoint.
		return p.lookupPaidExerciseIDViaSearch(c, catalogName)
	}

	want := strings.ToLower(strings.TrimSpace(catalogName))
	for _, ex := range parsed.Data {
		if strings.ToLower(strings.TrimSpace(ex.Name)) == want {
			if id := strings.TrimSpace(ex.ExerciseID); id != "" {
				return id, nil
			}
		}
	}
	if id := strings.TrimSpace(parsed.Data[0].ExerciseID); id != "" {
		return id, nil
	}
	return "", fmt.Errorf("rapidapi filter: no exercise id for %q", catalogName)
}

func (p *GIFProxy) lookupPaidExerciseIDViaSearch(c *gin.Context, catalogName string) (string, error) {
	u := url.URL{
		Scheme: "https",
		Host:   p.cfg.APIHost,
		Path:   "/api/v1/exercises/search",
	}
	q := u.Query()
	q.Set("search", catalogName)
	u.RawQuery = q.Encode()

	body, _, err := p.doRapidAPIJSON(c, u.String(), p.cfg.APIHost)
	if err != nil {
		return "", fmt.Errorf("rapidapi search: %w", err)
	}

	var parsed struct {
		Success bool            `json:"success"`
		Data    []rapidExercise `json:"data"`
	}
	if err := json.Unmarshal(body, &parsed); err != nil {
		return "", fmt.Errorf("rapidapi search parse failed")
	}
	if !parsed.Success || len(parsed.Data) == 0 {
		return "", fmt.Errorf("rapidapi search: no results for %q", catalogName)
	}
	if id := strings.TrimSpace(parsed.Data[0].ExerciseID); id != "" {
		return id, nil
	}
	return "", fmt.Errorf("rapidapi search: missing exercise id")
}

func (p *GIFProxy) fetchImageStream(c *gin.Context, imageURL, rapidHost, exerciseID string) (io.ReadCloser, string, error) {
	u, err := url.Parse(imageURL)
	if err != nil {
		return nil, "", err
	}
	q := u.Query()
	q.Set("exerciseId", exerciseID)
	q.Set("resolution", p.cfg.Resolution)
	u.RawQuery = q.Encode()
	return p.doGETImage(c, u.String(), rapidHost)
}

func (p *GIFProxy) fetchViaExerciseMetadata(c *gin.Context, exerciseID string) (io.ReadCloser, string, error) {
	metaURL := fmt.Sprintf("https://%s/api/v1/exercises/%s", p.cfg.APIHost, url.PathEscape(exerciseID))
	body, _, err := p.doRapidAPIJSON(c, metaURL, p.cfg.APIHost)
	if err != nil {
		return nil, "", fmt.Errorf("rapidapi metadata: %w", err)
	}

	var parsed struct {
		Success bool          `json:"success"`
		Data    rapidExercise `json:"data"`
	}
	if err := json.Unmarshal(body, &parsed); err != nil {
		return nil, "", fmt.Errorf("rapidapi metadata parse failed")
	}
	if !parsed.Success {
		return nil, "", fmt.Errorf("rapidapi metadata: exercise not found")
	}

	gifURL := pickGIFURL(parsed.Data.GifURLs, parsed.Data.GifURL, p.cfg.Resolution)
	if gifURL == "" {
		return nil, "", fmt.Errorf("rapidapi metadata: no gif url")
	}
	return p.doGETImage(c, normalizeAssetGIFURL(gifURL), "")
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
	replacements := []struct{ from, to string }{
		{"https://static.exercisedb.dev/media/", "https://assets.exercisedb.dev/media/"},
		{"http://static.exercisedb.dev/media/", "https://assets.exercisedb.dev/media/"},
	}
	for _, r := range replacements {
		raw = strings.Replace(raw, r.from, r.to, 1)
	}
	return raw
}

func (p *GIFProxy) doGETImage(c *gin.Context, rawURL, rapidHost string) (io.ReadCloser, string, error) {
	data, ct, err := p.doGETBytes(c, rawURL, rapidHost, false)
	if err != nil {
		return nil, "", err
	}
	return io.NopCloser(bytes.NewReader(data)), ct, nil
}

func (p *GIFProxy) doRapidAPIJSON(c *gin.Context, rawURL, rapidHost string) ([]byte, string, error) {
	return p.doGETBytes(c, rawURL, rapidHost, true)
}

func (p *GIFProxy) doGETBytes(c *gin.Context, rawURL, rapidHost string, expectJSON bool) ([]byte, string, error) {
	req, err := http.NewRequestWithContext(c.Request.Context(), http.MethodGet, rawURL, nil)
	if err != nil {
		return nil, "", err
	}
	if rapidHost != "" {
		req.Header.Set("X-RapidAPI-Key", p.cfg.RapidAPIKey)
		req.Header.Set("X-RapidAPI-Host", rapidHost)
		req.Header.Set("Content-Type", "application/json")
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
		if len(snippet) > 160 {
			snippet = snippet[:160]
		}
		return nil, "", fmt.Errorf("upstream HTTP %d: %s", resp.StatusCode, snippet)
	}

	ct := strings.ToLower(resp.Header.Get("Content-Type"))
	if expectJSON {
		if !strings.Contains(ct, "json") && !strings.HasPrefix(strings.TrimSpace(string(data)), "{") {
			return nil, "", fmt.Errorf("expected JSON, got %s", ct)
		}
		return data, resp.Header.Get("Content-Type"), nil
	}
	if !strings.HasPrefix(ct, "image/") {
		return nil, "", fmt.Errorf("expected image, got %s", ct)
	}
	return data, resp.Header.Get("Content-Type"), nil
}
