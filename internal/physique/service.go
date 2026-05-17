package physique

import (
	"context"

	"gainsai/internal/config"
)

const maxImagesPerScan = 3

type Service struct {
	repo   *Repository
	store  *Storage
	cfg    *config.Config
}

func NewService(repo *Repository, store *Storage, cfg *config.Config) *Service {
	return &Service{repo: repo, store: store, cfg: cfg}
}

func (s *Service) CreateScan(ctx context.Context, userID string, files []uploadedFile) (*Scan, error) {
	if len(files) == 0 {
		return nil, ErrNoImages
	}
	if len(files) > maxImagesPerScan {
		return nil, ErrTooManyImages
	}

	scanID, err := s.repo.NewScanID(ctx)
	if err != nil {
		return nil, err
	}

	saved, err := s.store.SaveScanImages(userID, scanID, files)
	if err != nil {
		return nil, err
	}

	visionImages := make([]visionImage, len(saved))
	for i, img := range saved {
		visionImages[i] = visionImage{MimeType: img.MimeType, Data: img.Data}
	}

	estimate, err := visionEstimate(ctx, s.cfg.OpenAIAPIKey, s.cfg.PhysiqueScanModel, visionImages)
	if err != nil {
		return nil, err
	}

	imageURL := saved[0].PublicURL
	return s.repo.Insert(ctx, userID, scanID, imageURL, estimate.EstimatedBodyFatPct, estimate.Confidence)
}

func (s *Service) GetScan(ctx context.Context, userID, scanID string) (*Scan, error) {
	return s.repo.GetByID(ctx, userID, scanID)
}

func (s *Service) ListScans(ctx context.Context, userID string, limit int) ([]Scan, error) {
	return s.repo.ListByUser(ctx, userID, limit)
}
