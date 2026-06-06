package ai

import (
	"context"
	"errors"
	"strings"

	"gainsai/internal/actionengine"
	"gainsai/internal/aiquota"
)

// Chat sends a user message and returns the assistant reply. New conversations receive coach context once.
func (s *Service) Chat(ctx context.Context, userID string, req ChatRequest) (*ChatResponse, error) {
	msg := trimMessage(req.Message)
	if msg == "" {
		return nil, ErrChatMessageRequired
	}
	if strings.TrimSpace(s.cfg.OpenAIAPIKey) == "" {
		return nil, ErrOpenAINotConfigured
	}
	if s.chat == nil {
		return nil, errors.New("chat repository not configured")
	}
	if err := s.quota.Consume(ctx, userID, aiquota.KindCoachMessage); err != nil {
		return nil, err
	}

	var convID string

	if req.ConversationID != nil && strings.TrimSpace(*req.ConversationID) != "" {
		convID = strings.TrimSpace(*req.ConversationID)
		conv, err := s.chat.GetConversationForUser(ctx, userID, convID)
		if err != nil {
			return nil, err
		}
		if conv == nil {
			return nil, ErrConversationNotFound
		}
	} else {
		conv, err := s.chat.CreateConversation(ctx, userID, conversationTitleFromMessage(msg))
		if err != nil {
			return nil, err
		}
		convID = conv.ID

		coachJSON, err := s.analytics.CoachContextJSON(ctx, userID)
		if err != nil {
			return nil, err
		}
		coachJSON, err = s.enrichCoachContextJSON(ctx, coachJSON)
		if err != nil {
			return nil, err
		}
		_, err = s.chat.InsertMessage(ctx, convID, ChatRoleSystem, coachContextUserPrefix+string(coachJSON))
		if err != nil {
			return nil, err
		}
	}

	if _, err := s.chat.InsertMessage(ctx, convID, ChatRoleUser, msg); err != nil {
		return nil, err
	}

	history, err := s.chat.ListMessagesForOpenAI(ctx, convID, coachChatMaxOpenAIMessages)
	if err != nil {
		return nil, err
	}

	openAIMsgs := make([]openAIChatMessage, 0, len(history)+1)
	systemPrompt, err := s.coachChatSystemPrompt(ctx)
	if err != nil {
		return nil, err
	}
	systemPrompt += unitDisplayInstruction(normalizeUnitSystem(req.UnitSystem))
	openAIMsgs = append(openAIMsgs, openAIChatMessage{Role: "system", Content: systemPrompt})
	for _, m := range history {
		openAIMsgs = append(openAIMsgs, openAIChatMessage{Role: m.Role, Content: m.Content})
	}

	model := s.cfg.OpenAIModel
	if model == "" {
		model = "gpt-4o-mini"
	}
	reply, err := ChatCompletionMessagesJSON(ctx, s.cfg.OpenAIAPIKey, model, openAIMsgs, coachChatMaxTokens)
	if err != nil {
		return nil, err
	}

	parsed, _ := parseCoachChatLLM(reply)
	display := strings.TrimSpace(parsed.Message)
	if display == "" {
		display = strings.TrimSpace(reply)
	}

	assistant, err := s.chat.InsertMessage(ctx, convID, ChatRoleAssistant, display)
	if err != nil {
		return nil, err
	}
	_ = s.chat.TouchConversation(ctx, convID)

	proposed, clar, err := s.persistProposedActions(ctx, userID, convID, parsed.ProposedActions)
	if err != nil {
		return nil, err
	}
	if len(parsed.ProposedActions) > 0 && len(proposed) == 0 && clar == nil {
		clar = actionsCouldNotBeAppliedClarification()
	}

	return &ChatResponse{
		ConversationID:  convID,
		Assistant:       *assistant,
		ProposedActions: proposed,
		Clarification:   clar,
	}, nil
}

// ListChatConversations returns the user's coach threads (no OpenAI).
func (s *Service) ListChatConversations(ctx context.Context, userID string, limit int) (*ConversationListResponse, error) {
	list, err := s.chat.ListConversations(ctx, userID, limit)
	if err != nil {
		return nil, err
	}
	if list == nil {
		list = []CoachConversation{}
	}
	return &ConversationListResponse{Conversations: list}, nil
}

// GetChatMessages returns user/assistant messages for a conversation (no OpenAI).
func (s *Service) GetChatMessages(ctx context.Context, userID, conversationID string) (*ConversationMessagesResponse, error) {
	conv, err := s.chat.GetConversationForUser(ctx, userID, conversationID)
	if err != nil {
		return nil, err
	}
	if conv == nil {
		return nil, ErrConversationNotFound
	}
	msgs, err := s.chat.ListVisibleMessages(ctx, conversationID, 200)
	if err != nil {
		return nil, err
	}
	if msgs == nil {
		msgs = []CoachMessage{}
	}
	return &ConversationMessagesResponse{
		ConversationID: conversationID,
		Messages:       msgs,
	}, nil
}

// DeleteChatConversation removes a coach thread and its messages. Pending actions from that chat are rejected.
func (s *Service) DeleteChatConversation(ctx context.Context, userID, conversationID string) error {
	if s.chat == nil {
		return errors.New("chat repository not configured")
	}
	conv, err := s.chat.GetConversationForUser(ctx, userID, conversationID)
	if err != nil {
		return err
	}
	if conv == nil {
		return ErrConversationNotFound
	}
	if s.actions != nil {
		_ = s.actions.RejectPendingBySource(ctx, userID, actionengine.SourceTypeChat, conversationID)
	}
	return s.chat.DeleteConversationForUser(ctx, userID, conversationID)
}
