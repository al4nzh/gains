package ai

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type RoutineDraftRepository struct {
	pool *pgxpool.Pool
}

func NewRoutineDraftRepository(pool *pgxpool.Pool) *RoutineDraftRepository {
	return &RoutineDraftRepository{pool: pool}
}

func (r *RoutineDraftRepository) Insert(ctx context.Context, userID, requestMessage, title string, draft storedRoutineDraft) (string, error) {
	raw, err := json.Marshal(draft)
	if err != nil {
		return "", err
	}
	var id string
	err = r.pool.QueryRow(ctx, `
		INSERT INTO ai_routine_drafts (user_id, request_message, title, draft_json, status)
		VALUES ($1::uuid, $2, $3, $4::jsonb, $5)
		RETURNING id::text`,
		userID, requestMessage, title, raw, RoutineDraftStatusDraft,
	).Scan(&id)
	return id, err
}

func (r *RoutineDraftRepository) GetForUser(ctx context.Context, userID, draftID string) (*routineDraftRow, error) {
	const q = `
		SELECT id::text, user_id::text, request_message, title, status, created_at, confirmed_at,
			draft_json
		FROM ai_routine_drafts
		WHERE id = $1::uuid AND user_id = $2::uuid`
	var row routineDraftRow
	var confirmed *time.Time
	var draftRaw []byte
	err := r.pool.QueryRow(ctx, q, draftID, userID).Scan(
		&row.ID, &row.UserID, &row.RequestMessage, &row.Title, &row.Status, &row.CreatedAt, &confirmed, &draftRaw,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrRoutineDraftNotFound
		}
		return nil, err
	}
	row.ConfirmedAt = confirmed
	if err := json.Unmarshal(draftRaw, &row.Payload); err != nil {
		return nil, err
	}
	return &row, nil
}

func (r *RoutineDraftRepository) MarkConfirmed(ctx context.Context, userID, draftID string) error {
	tag, err := r.pool.Exec(ctx, `
		UPDATE ai_routine_drafts
		SET status = $3, confirmed_at = NOW()
		WHERE id = $1::uuid AND user_id = $2::uuid AND status = $4`,
		draftID, userID, RoutineDraftStatusConfirmed, RoutineDraftStatusDraft,
	)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrRoutineDraftNotPending
	}
	return nil
}
