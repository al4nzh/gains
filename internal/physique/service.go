package physique

import (
	"context"

	"gainsai/internal/config"
)

const maxImagesPerScan = 3

type Service struct {
	repo *Repository
	cfg  *config.Config
}

func NewService(repo *Repository, cfg *config.Config) *Service {
	return &Service{repo: repo, cfg: cfg}
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

	visionImages := make([]visionImage, len(files))
	for i, f := range files {
		visionImages[i] = visionImage{MimeType: f.MimeType, Data: f.Data}
	}

	estimate, err := visionEstimate(ctx, s.cfg.OpenAIAPIKey, s.cfg.PhysiqueScanModel, visionImages)
	if err != nil {
		return nil, err
	}

	return s.repo.Insert(ctx, userID, scanID, estimate.EstimatedBodyFatPct, estimate.Confidence, estimate.Summary, estimate.Reasoning)
}

func (s *Service) GetScan(ctx context.Context, userID, scanID string) (*Scan, error) {
	return s.repo.GetByID(ctx, userID, scanID)
}

func (s *Service) ListScans(ctx context.Context, userID string, limit int) ([]Scan, error) {
	return s.repo.ListByUser(ctx, userID, limit)
}
