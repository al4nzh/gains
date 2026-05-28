package exercisedb

import (
	"context"
	"strings"
	"sync"
)

type index struct {
	byNormName map[string][]Exercise
}

func buildIndex(exercises []Exercise) *index {
	by := make(map[string][]Exercise, len(exercises))
	for _, ex := range exercises {
		if ex.GifURL == "" {
			continue
		}
		key := normalizeName(ex.Name)
		by[key] = append(by[key], ex)
	}
	return &index{byNormName: by}
}

func (idx *index) lookupExact(normName string) *Exercise {
	for _, ex := range idx.byNormName[normName] {
		return &ex
	}
	return nil
}

func (idx *index) candidatesContainingAllTokens(normName string, catalogTokens []string) []Exercise {
	if len(catalogTokens) == 0 {
		return nil
	}
	var out []Exercise
	for key, list := range idx.byNormName {
		ok := true
		for _, t := range catalogTokens {
			if t == "" {
				continue
			}
			if !stringsContainsToken(key, t) {
				ok = false
				break
			}
		}
		if ok {
			out = append(out, list...)
		}
	}
	return out
}

func stringsContainsToken(haystack, token string) bool {
	return strings.Contains(haystack, token)
}

type indexLoader struct {
	mu      sync.Mutex
	loaded  bool
	idx     *index
	loadErr error
}

func (l *indexLoader) get(ctx context.Context, client *Client) (*index, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.loaded {
		return l.idx, l.loadErr
	}
	all, err := client.ListAll(ctx)
	if err != nil {
		l.loadErr = err
		l.loaded = true
		return nil, err
	}
	l.idx = buildIndex(all)
	l.loaded = true
	return l.idx, nil
}
