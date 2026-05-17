package physique

import "errors"

var (
	ErrNotFound            = errors.New("physique scan not found")
	ErrOpenAINotConfigured = errors.New("openai api key not configured")
	ErrNoImages            = errors.New("at least one image is required")
	ErrTooManyImages       = errors.New("too many images")
	ErrImageTooLarge       = errors.New("image too large")
	ErrUnsupportedImage    = errors.New("unsupported image type")
)
