package subscription

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"gainsai/internal/user"
)

type webhookHandler struct {
	users         *user.Repository
	webhookSecret string
	entitlementID string
}

func NewWebhookHandler(users *user.Repository, webhookSecret, entitlementID string) *webhookHandler {
	entitlementID = strings.TrimSpace(entitlementID)
	if entitlementID == "" {
		entitlementID = "premium"
	}
	return &webhookHandler{
		users:         users,
		webhookSecret: strings.TrimSpace(webhookSecret),
		entitlementID: entitlementID,
	}
}

func (h *webhookHandler) RegisterRoutes(r *gin.Engine) {
	r.POST("/webhooks/revenuecat", h.revenueCat)
}

type revenueCatEvent struct {
	Event struct {
		Type            string   `json:"type"`
		AppUserID       string   `json:"app_user_id"`
		EntitlementIDs  []string `json:"entitlement_ids"`
		TransferredFrom []string `json:"transferred_from"`
		TransferredTo   []string `json:"transferred_to"`
	} `json:"event"`
}

func (h *webhookHandler) revenueCat(c *gin.Context) {
	if h.webhookSecret == "" {
		c.JSON(http.StatusNotFound, gin.H{"error": "not configured"})
		return
	}
	authHeader := strings.TrimSpace(c.GetHeader("Authorization"))
	if authHeader != h.webhookSecret && authHeader != "Bearer "+h.webhookSecret {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	body, err := io.ReadAll(io.LimitReader(c.Request.Body, 1<<20))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid body"})
		return
	}

	var payload revenueCatEvent
	if err := json.Unmarshal(body, &payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid json"})
		return
	}

	eventType := strings.TrimSpace(payload.Event.Type)
	if eventType == "TRANSFER" {
		h.handleTransfer(c, payload)
		return
	}

	userID := strings.TrimSpace(payload.Event.AppUserID)
	if userID == "" {
		c.JSON(http.StatusOK, gin.H{"ok": true, "skipped": "no app_user_id"})
		return
	}

	premium := h.isPremiumEvent(eventType, payload.Event.EntitlementIDs)
	if err := h.users.SetPremium(c.Request.Context(), userID, premium); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true, "is_premium": premium})
}

func (h *webhookHandler) handleTransfer(c *gin.Context, payload revenueCatEvent) {
	ctx := c.Request.Context()
	premium := h.isPremiumEvent("TRANSFER", payload.Event.EntitlementIDs)
	// TRANSFER events often omit entitlement_ids; an active sub move still grants premium.
	if !premium && len(payload.Event.TransferredTo) > 0 {
		premium = true
	}

	updated := make(map[string]bool)
	for _, raw := range payload.Event.TransferredFrom {
		id := strings.TrimSpace(raw)
		if id == "" {
			continue
		}
		if err := h.users.SetPremium(ctx, id, false); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
			return
		}
		updated[id] = false
	}
	for _, raw := range payload.Event.TransferredTo {
		id := strings.TrimSpace(raw)
		if id == "" {
			continue
		}
		if err := h.users.SetPremium(ctx, id, premium); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
			return
		}
		updated[id] = premium
	}

	if len(updated) == 0 {
		c.JSON(http.StatusOK, gin.H{"ok": true, "skipped": "no transfer users"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true, "transfer": updated})
}

func (h *webhookHandler) isPremiumEvent(eventType string, entitlementIDs []string) bool {
	switch eventType {
	case "INITIAL_PURCHASE", "RENEWAL", "UNCANCELLATION", "NON_RENEWING_PURCHASE", "PRODUCT_CHANGE", "TRANSFER":
		return hasEntitlement(entitlementIDs, h.entitlementID)
	case "EXPIRATION", "CANCELLATION", "BILLING_ISSUE":
		return false
	default:
		return hasEntitlement(entitlementIDs, h.entitlementID)
	}
}

func hasEntitlement(ids []string, want string) bool {
	for _, id := range ids {
		if strings.EqualFold(strings.TrimSpace(id), want) {
			return true
		}
	}
	return false
}
