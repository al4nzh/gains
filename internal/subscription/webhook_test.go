package subscription

import "testing"

func TestIsPremiumEvent(t *testing.T) {
	h := &webhookHandler{entitlementID: "premium"}

	if !h.isPremiumEvent("INITIAL_PURCHASE", []string{"premium"}) {
		t.Fatal("expected premium purchase")
	}
	if h.isPremiumEvent("CANCELLATION", []string{"premium"}) {
		t.Fatal("expected cancellation to clear premium")
	}
	if !h.isPremiumEvent("TRANSFER", []string{"premium"}) {
		t.Fatal("expected transfer with entitlement")
	}
}

func TestHasEntitlement(t *testing.T) {
	if !hasEntitlement([]string{"Premium"}, "premium") {
		t.Fatal("expected case-insensitive match")
	}
	if hasEntitlement([]string{"other"}, "premium") {
		t.Fatal("expected no match")
	}
}
