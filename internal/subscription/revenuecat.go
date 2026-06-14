package subscription

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const revenueCatAPIBase = "https://api.revenuecat.com/v1"

type RevenueCatClient struct {
	secretKey     string
	entitlementID string
	httpClient    *http.Client
}

func NewRevenueCatClient(secretKey, entitlementID string) *RevenueCatClient {
	entitlementID = strings.TrimSpace(entitlementID)
	if entitlementID == "" {
		entitlementID = "premium"
	}
	return &RevenueCatClient{
		secretKey:     strings.TrimSpace(secretKey),
		entitlementID: entitlementID,
		httpClient:    &http.Client{Timeout: 12 * time.Second},
	}
}

func (c *RevenueCatClient) Configured() bool {
	return c != nil && c.secretKey != ""
}

type revenueCatSubscriberResponse struct {
	RequestDate string `json:"request_date"`
	Subscriber  struct {
		Entitlements map[string]revenueCatEntitlement `json:"entitlements"`
	} `json:"subscriber"`
}

type revenueCatEntitlement struct {
	ExpiresDate            *string `json:"expires_date"`
	GracePeriodExpiresDate *string `json:"grace_period_expires_date"`
}

func (c *RevenueCatClient) HasActiveEntitlement(ctx context.Context, appUserID string) (bool, error) {
	if !c.Configured() {
		return false, fmt.Errorf("revenuecat not configured")
	}
	appUserID = strings.TrimSpace(appUserID)
	if appUserID == "" {
		return false, fmt.Errorf("empty app user id")
	}

	reqURL := revenueCatAPIBase + "/subscribers/" + url.PathEscape(appUserID)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, reqURL, nil)
	if err != nil {
		return false, err
	}
	req.Header.Set("Authorization", "Bearer "+c.secretKey)
	req.Header.Set("Accept", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return false, err
	}
	if resp.StatusCode != http.StatusOK {
		return false, fmt.Errorf("revenuecat api status %d", resp.StatusCode)
	}

	var payload revenueCatSubscriberResponse
	if err := json.Unmarshal(body, &payload); err != nil {
		return false, err
	}

	ent, ok := findEntitlement(payload.Subscriber.Entitlements, c.entitlementID)
	if !ok {
		return false, nil
	}
	return entitlementActive(ent, payload.RequestDate), nil
}

func findEntitlement(all map[string]revenueCatEntitlement, want string) (revenueCatEntitlement, bool) {
	for id, ent := range all {
		if strings.EqualFold(strings.TrimSpace(id), want) {
			return ent, true
		}
	}
	return revenueCatEntitlement{}, false
}

func entitlementActive(ent revenueCatEntitlement, requestDate string) bool {
	if ent.ExpiresDate == nil || strings.TrimSpace(*ent.ExpiresDate) == "" {
		return true
	}
	expires, err := time.Parse(time.RFC3339, strings.TrimSpace(*ent.ExpiresDate))
	if err != nil {
		return false
	}
	ref := time.Now().UTC()
	if requestDate != "" {
		if parsed, err := time.Parse(time.RFC3339, strings.TrimSpace(requestDate)); err == nil {
			ref = parsed
		}
	}
	if ent.GracePeriodExpiresDate != nil && strings.TrimSpace(*ent.GracePeriodExpiresDate) != "" {
		if grace, err := time.Parse(time.RFC3339, strings.TrimSpace(*ent.GracePeriodExpiresDate)); err == nil {
			if grace.After(ref) {
				return true
			}
		}
	}
	return expires.After(ref)
}
