package ai

import "time"

const (
	ChatRoleSystem    = "system"
	ChatRoleUser      = "user"
	ChatRoleAssistant = "assistant"

	coachChatMaxOpenAIMessages = 40
	coachChatTitleMaxRunes     = 60
)

// CoachConversation is one coach chat thread for a user.
type CoachConversation struct {
	ID        string    `json:"id"`
	UserID    string    `json:"user_id,omitempty"`
	Title     string    `json:"title"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// CoachMessage is one row in a coach conversation (API omits system/context rows).
type CoachMessage struct {
	ID             string    `json:"id"`
	ConversationID string    `json:"conversation_id,omitempty"`
	Role           string    `json:"role"`
	Content        string    `json:"content"`
	CreatedAt      time.Time `json:"created_at"`
}

// ChatRequest is POST /ai/chat body.
type ChatRequest struct {
	Message        string  `json:"message"`
	ConversationID *string `json:"conversation_id,omitempty"`
}

// ChatResponse is POST /ai/chat 200 body.
type ChatResponse struct {
	ConversationID string       `json:"conversation_id"`
	Assistant      CoachMessage `json:"assistant"`
}

// ConversationListResponse is GET /ai/chat/conversations.
type ConversationListResponse struct {
	Conversations []CoachConversation `json:"conversations"`
}

// ConversationMessagesResponse is GET /ai/chat/conversations/:id/messages.
type ConversationMessagesResponse struct {
	ConversationID string         `json:"conversation_id"`
	Messages       []CoachMessage `json:"messages"`
}
