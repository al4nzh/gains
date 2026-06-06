package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

const openAIBaseURL = "https://api.openai.com/v1/chat/completions"

const (
	analyzeWorkoutMaxTokens = 280
	coachChatMaxTokens      = 700 // short message + proposed_actions JSON
)

type openAIChatRequest struct {
	Model          string              `json:"model"`
	Messages       []openAIChatMessage `json:"messages"`
	MaxTokens      *int                `json:"max_tokens,omitempty"`
	ResponseFormat *openAIRespFormat   `json:"response_format,omitempty"`
}

type openAIRespFormat struct {
	Type string `json:"type"`
}

type openAIChatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type openAIChatResponse struct {
	Choices []struct {
		Message struct {
			Content string `json:"content"`
		} `json:"message"`
	} `json:"choices"`
	Error *struct {
		Message string `json:"message"`
		Type    string `json:"type"`
	} `json:"error"`
}

// ChatCompletion calls OpenAI chat completions with a single system + user message.
func ChatCompletion(ctx context.Context, apiKey, model, systemPrompt, userContent string, maxTokens int) (string, error) {
	return ChatCompletionMessages(ctx, apiKey, model, []openAIChatMessage{
		{Role: "system", Content: systemPrompt},
		{Role: "user", Content: userContent},
	}, maxTokens)
}

// ChatCompletionMessages calls OpenAI with a full message list (roles: system, user, assistant).
func ChatCompletionMessages(ctx context.Context, apiKey, model string, messages []openAIChatMessage, maxTokens int) (string, error) {
	return chatCompletionMessages(ctx, apiKey, model, messages, false, maxTokens)
}

// ChatCompletionMessagesJSON requests a JSON object response (e.g. coach chat with proposed_actions).
func ChatCompletionMessagesJSON(ctx context.Context, apiKey, model string, messages []openAIChatMessage, maxTokens int) (string, error) {
	return chatCompletionMessages(ctx, apiKey, model, messages, true, maxTokens)
}

func chatCompletionMessages(ctx context.Context, apiKey, model string, messages []openAIChatMessage, jsonObject bool, maxTokens int) (string, error) {
	if strings.TrimSpace(apiKey) == "" {
		return "", ErrOpenAINotConfigured
	}
	if model == "" {
		model = "gpt-4o-mini"
	}
	if len(messages) == 0 {
		return "", errors.New("openai: no messages")
	}
	body := openAIChatRequest{
		Model:    model,
		Messages: messages,
	}
	if maxTokens > 0 {
		body.MaxTokens = &maxTokens
	}
	if jsonObject {
		body.ResponseFormat = &openAIRespFormat{Type: "json_object"}
	}
	raw, err := json.Marshal(body)
	if err != nil {
		return "", err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, openAIBaseURL, bytes.NewReader(raw))
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 120 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}
	var parsed openAIChatResponse
	if err := json.Unmarshal(respBody, &parsed); err != nil {
		return "", fmt.Errorf("openai: decode response: %w; body=%s", err, truncate(string(respBody), 500))
	}
	if parsed.Error != nil && parsed.Error.Message != "" {
		return "", fmt.Errorf("openai api: %s", parsed.Error.Message)
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", fmt.Errorf("openai http %d: %s", resp.StatusCode, truncate(string(respBody), 800))
	}
	if len(parsed.Choices) == 0 || strings.TrimSpace(parsed.Choices[0].Message.Content) == "" {
		return "", errors.New("openai: empty assistant content")
	}
	return strings.TrimSpace(parsed.Choices[0].Message.Content), nil
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "…"
}
