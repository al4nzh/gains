package physique

import (
	"errors"
	"mime/multipart"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"gainsai/internal/auth"
)

type Handler struct {
	svc *Service
}

func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

func (h *Handler) RegisterRoutes(r *gin.Engine, requireAuth, limiter gin.HandlerFunc) {
	g := r.Group("/physique-scans", requireAuth, limiter)
	g.POST("", h.create)
	g.GET("", h.list)
	g.GET("/:id", h.get)
}

func (h *Handler) create(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}

	files, err := collectUploads(c)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	scan, err := h.svc.CreateScan(c.Request.Context(), userID, files)
	if err != nil {
		writeCreateError(c, err)
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"id":                     scan.ID,
		"estimated_body_fat_pct": scan.EstimatedBodyFatPct,
		"confidence":             scan.Confidence,
		"image_url":              scan.ImageURL,
	})
}

func (h *Handler) list(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	limit := 50
	if q := c.Query("limit"); q != "" {
		if n, err := strconv.Atoi(q); err == nil {
			limit = n
		}
	}
	scans, err := h.svc.ListScans(c.Request.Context(), userID, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	if scans == nil {
		scans = []Scan{}
	}
	c.JSON(http.StatusOK, gin.H{"scans": scans})
}

func (h *Handler) get(c *gin.Context) {
	userID, ok := auth.UserIDFromContext(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthenticated"})
		return
	}
	scan, err := h.svc.GetScan(c.Request.Context(), userID, c.Param("id"))
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "scan not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	c.JSON(http.StatusOK, scan)
}

func collectUploads(c *gin.Context) ([]uploadedFile, error) {
	form, err := c.MultipartForm()
	if err != nil {
		return nil, ErrNoImages
	}
	var headers []*multipart.FileHeader
	if form != nil {
		headers = append(headers, form.File["images"]...)
		if len(headers) == 0 {
			headers = form.File["image"]
		}
	}
	if len(headers) == 0 {
		if fh, err := c.FormFile("image"); err == nil {
			headers = []*multipart.FileHeader{fh}
		} else if fh, err := c.FormFile("images"); err == nil {
			headers = []*multipart.FileHeader{fh}
		}
	}
	if len(headers) == 0 {
		return nil, ErrNoImages
	}
	if len(headers) > maxImagesPerScan {
		return nil, ErrTooManyImages
	}

	out := make([]uploadedFile, 0, len(headers))
	for _, fh := range headers {
		f, err := fh.Open()
		if err != nil {
			return nil, err
		}
		uploaded, err := readUploadedFile(f, fh.Header.Get("Content-Type"), fh.Size)
		_ = f.Close()
		if err != nil {
			return nil, err
		}
		out = append(out, uploaded)
	}
	return out, nil
}

func writeCreateError(c *gin.Context, err error) {
	switch {
	case errors.Is(err, ErrNoImages):
		c.JSON(http.StatusBadRequest, gin.H{"error": "at least one image is required"})
	case errors.Is(err, ErrTooManyImages):
		c.JSON(http.StatusBadRequest, gin.H{"error": "maximum 3 images per scan"})
	case errors.Is(err, ErrImageTooLarge):
		c.JSON(http.StatusBadRequest, gin.H{"error": "image too large (max 8MB)"})
	case errors.Is(err, ErrUnsupportedImage):
		c.JSON(http.StatusBadRequest, gin.H{"error": "unsupported image type (use jpeg, png, or webp)"})
	case errors.Is(err, ErrOpenAINotConfigured):
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "AI is not configured (set OPENAI_API_KEY)"})
	default:
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
	}
}
