package exercisedb

import (
	"context"
	"fmt"
	"strings"
	"sync"
)

// LookupItem is one catalog exercise to resolve to a GIF URL.
type LookupItem struct {
	ID        string
	Name      string
	Equipment string
}

type Service struct {
	client  *Client
	enabled bool
	mu      sync.RWMutex
	cache   map[string]string // cache key -> gif URL
	index   indexLoader
}

func NewService(client *Client, enabled bool) *Service {
	return &Service{
		client:  client,
		enabled: enabled,
		cache:   make(map[string]string),
	}
}

func (s *Service) Enabled() bool {
	return s != nil && s.enabled && s.client != nil
}

func (s *Service) LookupGIFs(ctx context.Context, items []LookupItem) map[string]string {
	out := make(map[string]string, len(items))
	if !s.Enabled() || len(items) == 0 {
		return out
	}
	for _, item := range items {
		id := strings.TrimSpace(item.ID)
		if id == "" {
			continue
		}
		if url, ok := s.cached(item); ok {
			out[id] = url
			continue
		}
		url, err := s.resolve(ctx, item.Name, item.Equipment)
		if err != nil || url == "" {
			continue
		}
		s.putCache(item, url)
		out[id] = url
	}
	return out
}

func (s *Service) cacheKey(name, equipment string) string {
	return normalizeName(name) + "|" + strings.ToLower(strings.TrimSpace(equipment))
}

func (s *Service) cached(item LookupItem) (string, bool) {
	key := s.cacheKey(item.Name, item.Equipment)
	s.mu.RLock()
	url, ok := s.cache[key]
	s.mu.RUnlock()
	return url, ok
}

func (s *Service) putCache(item LookupItem, url string) {
	key := s.cacheKey(item.Name, item.Equipment)
	s.mu.Lock()
	s.cache[key] = url
	s.mu.Unlock()
}

func (s *Service) resolve(ctx context.Context, name, equipment string) (string, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return "", nil
	}
	key := normalizeName(name)

	if url, ok := staticCatalogGIFURL(key); ok {
		return url, nil
	}

	idx, err := s.index.get(ctx, s.client)
	if err != nil {
		return "", err
	}
	if idx != nil {
		target := normalizeName(preferredDBName(name))
		if ex := idx.lookupExact(target); ex != nil {
			return ex.GifURL, nil
		}
		cands := idx.candidatesContainingAllTokens(target, tokens(name))
		if picked := pickBest(name, equipment, cands); picked != nil {
			return picked.GifURL, nil
		}
	}

	return "", fmt.Errorf("no gif match for %q", name)
}

func (s *Service) gifURLByID(ctx context.Context, exerciseID string) string {
	ex, err := s.client.GetByID(ctx, exerciseID)
	if err != nil || ex == nil || ex.GifURL == "" {
		return ""
	}
	return ex.GifURL
}
