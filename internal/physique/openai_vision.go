package physique

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

const openAIBaseURL = "https://api.openai.com/v1/chat/completions"

type visionImage struct {
	MimeType string
	Data     []byte
}

type openAIChatRequest struct {
	Model    string              `json:"model"`
	Messages []openAIChatMessage `json:"messages"`
}

type openAIChatMessage struct {
	Role    string `json:"role"`
	Content any    `json:"content"`
}

type openAIContentPart struct {
	Type     string          `json:"type"`
	Text     string          `json:"text,omitempty"`
	ImageURL *openAIImageURL `json:"image_url,omitempty"`
}

type openAIImageURL struct {
	URL string `json:"url"`
}

type openAIChatResponse struct {
	Choices []struct {
		Message struct {
			Content string `json:"content"`
		} `json:"message"`
	} `json:"choices"`
	Error *struct {
		Message string `json:"message"`
	} `json:"error"`
}

func visionEstimate(ctx context.Context, apiKey, model string, images []visionImage) (EstimateResult, error) {
	if strings.TrimSpace(apiKey) == "" {
		return EstimateResult{}, ErrOpenAINotConfigured
	}
	if model == "" {
		model = "gpt-5.4-mini"
	}
	if len(images) == 0 {
		return EstimateResult{}, ErrNoImages
	}

	parts := []openAIContentPart{
		{Type: "text", Text: "Estimate body fat from the attached physique photo(s). Reply with JSON only."},
	}
	for _, img := range images {
		b64 := base64.StdEncoding.EncodeToString(img.Data)
		parts = append(parts, openAIContentPart{
			Type: "image_url",
			ImageURL: &openAIImageURL{
				URL: "data:" + img.MimeType + ";base64," + b64,
			},
		})
	}

	body := openAIChatRequest{
		Model: model,
		Messages: []openAIChatMessage{
			{Role: "system", Content: systemPrompt},
			{Role: "user", Content: parts},
		},
	}
	raw, err := json.Marshal(body)
	if err != nil {
		return EstimateResult{}, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, openAIBaseURL, bytes.NewReader(raw))
	if err != nil {
		return EstimateResult{}, err
	}
	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 90 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return EstimateResult{}, err
	}
	defer resp.Body.Close()
	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return EstimateResult{}, err
	}

	var parsed openAIChatResponse
	if err := json.Unmarshal(respBody, &parsed); err != nil {
		return EstimateResult{}, fmt.Errorf("openai: decode response: %w", err)
	}
	if parsed.Error != nil && parsed.Error.Message != "" {
		return EstimateResult{}, fmt.Errorf("openai api: %s", parsed.Error.Message)
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return EstimateResult{}, fmt.Errorf("openai http %d", resp.StatusCode)
	}
	if len(parsed.Choices) == 0 || strings.TrimSpace(parsed.Choices[0].Message.Content) == "" {
		return EstimateResult{}, errors.New("openai: empty assistant content")
	}

	return parseEstimateJSON(parsed.Choices[0].Message.Content)
}

func parseEstimateJSON(content string) (EstimateResult, error) {
	content = strings.TrimSpace(content)
	content = strings.TrimPrefix(content, "```json")
	content = strings.TrimPrefix(content, "```")
	content = strings.TrimSuffix(content, "```")
	content = strings.TrimSpace(content)

	var raw struct {
		EstimatedBodyFatPct float64 `json:"estimated_body_fat_pct"`
		Confidence          string  `json:"confidence"`
	}
	if err := json.Unmarshal([]byte(content), &raw); err != nil {
		return EstimateResult{}, fmt.Errorf("openai: invalid estimate json: %w", err)
	}

	pct := int(raw.EstimatedBodyFatPct + 0.5)
	if pct < 1 {
		pct = 1
	}
	if pct > 70 {
		pct = 70
	}

	conf := strings.ToLower(strings.TrimSpace(raw.Confidence))
	switch conf {
	case "low", "medium", "high":
	default:
		conf = "medium"
	}

	return EstimateResult{
		EstimatedBodyFatPct: pct,
		Confidence:          conf,
	}, nil
}
