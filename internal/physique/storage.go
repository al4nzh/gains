package physique

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

const maxImageBytes = 8 << 20 // 8 MiB

var allowedMIME = map[string]string{
	"image/jpeg": ".jpg",
	"image/png":  ".png",
	"image/webp": ".webp",
}

type savedImage struct {
	PublicURL string
	RelPath   string
	MimeType  string
	Data      []byte
}

type Storage struct {
	rootDir string
}

func (s *Storage) RootDir() string {
	return s.rootDir
}

func NewStorage(rootDir string) (*Storage, error) {
	rootDir = strings.TrimSpace(rootDir)
	if rootDir == "" {
		rootDir = "data/uploads/physique"
	}
	abs, err := filepath.Abs(rootDir)
	if err != nil {
		return nil, err
	}
	if err := os.MkdirAll(abs, 0o755); err != nil {
		return nil, err
	}
	return &Storage{rootDir: abs}, nil
}

func (s *Storage) SaveScanImages(userID, scanID string, files []uploadedFile) ([]savedImage, error) {
	dir := filepath.Join(s.rootDir, userID, scanID)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return nil, err
	}

	out := make([]savedImage, 0, len(files))
	for i, f := range files {
		ext, ok := allowedMIME[f.MimeType]
		if !ok {
			return nil, ErrUnsupportedImage
		}
		name := fmt.Sprintf("%d%s", i, ext)
		rel := filepath.ToSlash(filepath.Join(userID, scanID, name))
		full := filepath.Join(s.rootDir, userID, scanID, name)
		if err := os.WriteFile(full, f.Data, 0o644); err != nil {
			return nil, err
		}
		public := "/uploads/physique/" + rel
		out = append(out, savedImage{
			PublicURL: public,
			RelPath:   rel,
			MimeType:  f.MimeType,
			Data:      f.Data,
		})
	}
	return out, nil
}

type uploadedFile struct {
	MimeType string
	Data     []byte
}

func readUploadedFile(r io.Reader, mime string, size int64) (uploadedFile, error) {
	if size > maxImageBytes {
		return uploadedFile{}, ErrImageTooLarge
	}
	data, err := io.ReadAll(io.LimitReader(r, maxImageBytes+1))
	if err != nil {
		return uploadedFile{}, err
	}
	if int64(len(data)) > maxImageBytes {
		return uploadedFile{}, ErrImageTooLarge
	}
	mime = normalizeMIME(mime, data)
	if _, ok := allowedMIME[mime]; !ok {
		return uploadedFile{}, ErrUnsupportedImage
	}
	return uploadedFile{MimeType: mime, Data: data}, nil
}

func normalizeMIME(header string, data []byte) string {
	header = strings.ToLower(strings.TrimSpace(header))
	if header != "" && header != "application/octet-stream" {
		if i := strings.Index(header, ";"); i >= 0 {
			header = header[:i]
		}
		if _, ok := allowedMIME[header]; ok {
			return header
		}
	}
	switch {
	case len(data) >= 3 && data[0] == 0xFF && data[1] == 0xD8:
		return "image/jpeg"
	case len(data) >= 8 && string(data[0:8]) == "\x89PNG\r\n\x1a\n":
		return "image/png"
	case len(data) >= 12 && string(data[0:4]) == "RIFF" && string(data[8:12]) == "WEBP":
		return "image/webp"
	default:
		return header
	}
}
