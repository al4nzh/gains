package ai

import (
	"context"
	"errors"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type ChatRepository struct {
	pool *pgxpool.Pool
}

func NewChatRepository(pool *pgxpool.Pool) *ChatRepository {
	return &ChatRepository{pool: pool}
}

func (r *ChatRepository) CreateConversation(ctx context.Context, userID, title string) (*CoachConversation, error) {
	if title == "" {
		title = "Coach chat"
	}
	row := r.pool.QueryRow(ctx, `
		INSERT INTO coach_conversations (user_id, title)
		VALUES ($1::uuid, $2)
		RETURNING id::text, user_id::text, title, created_at, updated_at`,
		userID, title)
	var c CoachConversation
	if err := row.Scan(&c.ID, &c.UserID, &c.Title, &c.CreatedAt, &c.UpdatedAt); err != nil {
		return nil, err
	}
	return &c, nil
}

func (r *ChatRepository) TouchConversation(ctx context.Context, conversationID string) error {
	_, err := r.pool.Exec(ctx, `
		UPDATE coach_conversations SET updated_at = NOW() WHERE id = $1::uuid`, conversationID)
	return err
}

func (r *ChatRepository) GetConversationForUser(ctx context.Context, userID, conversationID string) (*CoachConversation, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT id::text, user_id::text, title, created_at, updated_at
		FROM coach_conversations
		WHERE id = $1::uuid AND user_id = $2::uuid`, conversationID, userID)
	var c CoachConversation
	if err := row.Scan(&c.ID, &c.UserID, &c.Title, &c.CreatedAt, &c.UpdatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &c, nil
}

func (r *ChatRepository) ListConversations(ctx context.Context, userID string, limit int) ([]CoachConversation, error) {
	if limit < 1 {
		limit = 30
	}
	if limit > 100 {
		limit = 100
	}
	rows, err := r.pool.Query(ctx, `
		SELECT id::text, user_id::text, title, created_at, updated_at
		FROM coach_conversations
		WHERE user_id = $1::uuid
		ORDER BY updated_at DESC
		LIMIT $2`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []CoachConversation
	for rows.Next() {
		var c CoachConversation
		if err := rows.Scan(&c.ID, &c.UserID, &c.Title, &c.CreatedAt, &c.UpdatedAt); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (r *ChatRepository) InsertMessage(ctx context.Context, conversationID, role, content string) (*CoachMessage, error) {
	row := r.pool.QueryRow(ctx, `
		INSERT INTO coach_messages (conversation_id, role, content)
		VALUES ($1::uuid, $2, $3)
		RETURNING id::text, conversation_id::text, role, content, created_at`,
		conversationID, role, content)
	var m CoachMessage
	if err := row.Scan(&m.ID, &m.ConversationID, &m.Role, &m.Content, &m.CreatedAt); err != nil {
		return nil, err
	}
	return &m, nil
}

func (r *ChatRepository) ListMessagesForOpenAI(ctx context.Context, conversationID string, limit int) ([]CoachMessage, error) {
	if limit < 1 {
		limit = coachChatMaxOpenAIMessages
	}
	rows, err := r.pool.Query(ctx, `
		SELECT id::text, conversation_id::text, role, content, created_at
		FROM (
			SELECT id, conversation_id, role, content, created_at
			FROM coach_messages
			WHERE conversation_id = $1::uuid
			ORDER BY created_at DESC
			LIMIT $2
		) sub
		ORDER BY created_at ASC`, conversationID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []CoachMessage
	for rows.Next() {
		var m CoachMessage
		if err := rows.Scan(&m.ID, &m.ConversationID, &m.Role, &m.Content, &m.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

func (r *ChatRepository) ListVisibleMessages(ctx context.Context, conversationID string, limit int) ([]CoachMessage, error) {
	if limit < 1 {
		limit = 100
	}
	if limit > 200 {
		limit = 200
	}
	rows, err := r.pool.Query(ctx, `
		SELECT id::text, conversation_id::text, role, content, created_at
		FROM (
			SELECT id, conversation_id, role, content, created_at
			FROM coach_messages
			WHERE conversation_id = $1::uuid AND role IN ('user', 'assistant')
			ORDER BY created_at DESC
			LIMIT $2
		) sub
		ORDER BY created_at ASC`, conversationID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []CoachMessage
	for rows.Next() {
		var m CoachMessage
		if err := rows.Scan(&m.ID, &m.ConversationID, &m.Role, &m.Content, &m.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

func conversationTitleFromMessage(msg string) string {
	msg = trimMessage(msg)
	runes := []rune(msg)
	if len(runes) > coachChatTitleMaxRunes {
		return string(runes[:coachChatTitleMaxRunes]) + "…"
	}
	if msg == "" {
		return "Coach chat"
	}
	return msg
}

func trimMessage(s string) string {
	const max = 8000
	s = strings.TrimSpace(s)
	if len(s) > max {
		return s[:max]
	}
	return s
}
