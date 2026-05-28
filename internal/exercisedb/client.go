package exercisedb

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

const defaultBaseURL = "https://oss.exercisedb.dev/api/v1"

// Exercise is a subset of the ExerciseDB OSS API exercise object.
type Exercise struct {
	ExerciseID string   `json:"exerciseId"`
	Name       string   `json:"name"`
	GifURL     string   `json:"gifUrl"`
	Equipments []string `json:"equipments"`
}

type Client struct {
	baseURL string
	http    *http.Client
}

func NewClient(baseURL string) *Client {
	baseURL = strings.TrimRight(strings.TrimSpace(baseURL), "/")
	if baseURL == "" {
		baseURL = defaultBaseURL
	}
	return &Client{
		baseURL: baseURL,
		http: &http.Client{
			Timeout: 12 * time.Second,
		},
	}
}

func (c *Client) GetByID(ctx context.Context, exerciseID string) (*Exercise, error) {
	exerciseID = strings.TrimSpace(exerciseID)
	if exerciseID == "" {
		return nil, fmt.Errorf("exercise id required")
	}
	var out struct {
		Success bool     `json:"success"`
		Data    Exercise `json:"data"`
	}
	if err := c.getJSON(ctx, "/exercises/"+url.PathEscape(exerciseID), nil, &out); err != nil {
		return nil, err
	}
	if !out.Success || out.Data.GifURL == "" {
		return nil, fmt.Errorf("exercise not found")
	}
	return &out.Data, nil
}

type listPageMeta struct {
	Total           int    `json:"total"`
	HasNextPage     bool   `json:"hasNextPage"`
	HasPreviousPage bool   `json:"hasPreviousPage"`
	NextCursor      string `json:"nextCursor"`
}

// ListPage returns one page of exercises. Pass empty cursor for the first page.
func (c *Client) ListPage(ctx context.Context, limit int, cursor string) ([]Exercise, listPageMeta, error) {
	if limit < 1 {
		limit = 100
	}
	if limit > 100 {
		limit = 100
	}
	var out struct {
		Success bool         `json:"success"`
		Meta    listPageMeta `json:"meta"`
		Data    []Exercise   `json:"data"`
	}
	q := url.Values{}
	q.Set("limit", strconv.Itoa(limit))
	if strings.TrimSpace(cursor) != "" {
		q.Set("cursor", strings.TrimSpace(cursor))
	}
	if err := c.getJSON(ctx, "/exercises", q, &out); err != nil {
		return nil, listPageMeta{}, err
	}
	if !out.Success {
		return nil, listPageMeta{}, fmt.Errorf("exercisedb: list failed")
	}
	return out.Data, out.Meta, nil
}

// ListAll downloads the full OSS dataset using cursor pagination.
func (c *Client) ListAll(ctx context.Context) ([]Exercise, error) {
	const pageSize = 100
	var all []Exercise
	cursor := ""
	for page := 0; page < 25; page++ {
		batch, meta, err := c.ListPage(ctx, pageSize, cursor)
		if err != nil {
			return nil, err
		}
		all = append(all, batch...)
		if !meta.HasNextPage || meta.NextCursor == "" {
			break
		}
		cursor = meta.NextCursor
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(2 * time.Second):
		}
	}
	return all, nil
}

func (c *Client) SearchByName(ctx context.Context, name string, limit int) ([]Exercise, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, nil
	}
	if limit < 1 {
		limit = 25
	}
	if limit > 50 {
		limit = 50
	}
	var out struct {
		Success bool       `json:"success"`
		Data    []Exercise `json:"data"`
	}
	q := url.Values{}
	q.Set("name", name)
	q.Set("limit", strconv.Itoa(limit))
	if err := c.getJSON(ctx, "/exercises", q, &out); err != nil {
		return nil, err
	}
	if !out.Success {
		return nil, nil
	}
	return out.Data, nil
}

func (c *Client) getJSON(ctx context.Context, path string, query url.Values, dest any) error {
	u, err := url.Parse(c.baseURL + path)
	if err != nil {
		return err
	}
	if len(query) > 0 {
		u.RawQuery = query.Encode()
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
	if err != nil {
		return err
	}
	body, status, err := c.doWithRetry(req)
	if err != nil {
		return err
	}
	if status != http.StatusOK {
		return fmt.Errorf("exercisedb: status %d", status)
	}
	if err := json.Unmarshal(body, dest); err != nil {
		return err
	}
	return nil
}

func (c *Client) doWithRetry(req *http.Request) ([]byte, int, error) {
	var lastStatus int
	for attempt := 0; attempt < 4; attempt++ {
		if attempt > 0 {
			wait := time.Duration(attempt*attempt) * 800 * time.Millisecond
			select {
			case <-req.Context().Done():
				return nil, 0, req.Context().Err()
			case <-time.After(wait):
			}
			req = req.Clone(req.Context())
		}
		res, err := c.http.Do(req)
		if err != nil {
			return nil, 0, err
		}
		body, err := io.ReadAll(io.LimitReader(res.Body, 2<<20))
		res.Body.Close()
		if err != nil {
			return nil, 0, err
		}
		lastStatus = res.StatusCode
		if res.StatusCode == http.StatusOK {
			return body, res.StatusCode, nil
		}
		if res.StatusCode != http.StatusTooManyRequests {
			return body, res.StatusCode, nil
		}
	}
	return nil, lastStatus, fmt.Errorf("exercisedb: rate limited")
}
