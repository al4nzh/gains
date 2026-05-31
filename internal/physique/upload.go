package physique

import (
	"io"
	"strings"
)

var allowedMIME = map[string]string{
	"image/jpeg": ".jpg",
	"image/png":  ".png",
	"image/webp": ".webp",
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

const maxImageBytes = 8 << 20 // 8 MiB
