package subscription

import (
	"testing"
	"time"
)

func TestEntitlementActive(t *testing.T) {
	now := time.Now().UTC().Format(time.RFC3339)
	future := time.Now().UTC().Add(24 * time.Hour).Format(time.RFC3339)
	past := time.Now().UTC().Add(-24 * time.Hour).Format(time.RFC3339)

	if !entitlementActive(revenueCatEntitlement{}, now) {
		t.Fatal("nil expires should be active")
	}
	if !entitlementActive(revenueCatEntitlement{ExpiresDate: &future}, now) {
		t.Fatal("future expires should be active")
	}
	if entitlementActive(revenueCatEntitlement{ExpiresDate: &past}, now) {
		t.Fatal("past expires should be inactive")
	}
}
