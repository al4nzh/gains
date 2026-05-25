package ai

import (
	"context"
	"database/sql"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"gainsai/internal/actionengine"
)

type ActionRepository struct {
	pool *pgxpool.Pool
}

func NewActionRepository(pool *pgxpool.Pool) *ActionRepository {
	return &ActionRepository{pool: pool}
}

type insertActionInput struct {
	UserID     string
	SourceType string
	SourceID   *string
	ActionType string
	TargetType string
	TargetID   *string
	Payload    []byte
	Reason     *string
}

func (r *ActionRepository) Insert(ctx context.Context, in insertActionInput) (*actionengine.Action, error) {
	const q = `
		INSERT INTO ai_actions (
			user_id, source_type, source_id, action_type, target_type, target_id, payload, reason, status
		) VALUES (
			$1::uuid, $2, $3::uuid, $4, $5, $6::uuid, $7::jsonb, $8, $9
		)
		RETURNING id::text, user_id::text, insight_id::text,
			source_type, source_id::text, action_type, target_type, target_id::text,
			COALESCE(payload, '{}'::jsonb), reason, status, created_at, resolved_at, applied_at`
	row := r.pool.QueryRow(ctx, q,
		in.UserID, in.SourceType, in.SourceID, in.ActionType, in.TargetType, in.TargetID,
		in.Payload, in.Reason, actionengine.StatusPending,
	)
	return scanActionRow(row)
}

func (r *ActionRepository) GetForUser(ctx context.Context, userID, actionID string) (*actionengine.Action, error) {
	const q = `
		SELECT id::text, user_id::text, insight_id::text,
			source_type, source_id::text, action_type, target_type, target_id::text,
			COALESCE(payload, '{}'::jsonb), reason, status, created_at, resolved_at, applied_at
		FROM ai_actions
		WHERE id = $1::uuid AND user_id = $2::uuid`
	row := r.pool.QueryRow(ctx, q, actionID, userID)
	a, err := scanActionRow(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrActionNotFound
		}
		return nil, err
	}
	return a, nil
}

func (r *ActionRepository) ListPending(ctx context.Context, userID string, limit int) ([]actionengine.Action, error) {
	if limit < 1 {
		limit = 50
	}
	if limit > 100 {
		limit = 100
	}
	rows, err := r.pool.Query(ctx, `
		SELECT id::text, user_id::text, insight_id::text,
			source_type, source_id::text, action_type, target_type, target_id::text,
			COALESCE(payload, '{}'::jsonb), reason, status, created_at, resolved_at, applied_at
		FROM ai_actions
		WHERE user_id = $1::uuid AND status = $2
		ORDER BY created_at DESC
		LIMIT $3`, userID, actionengine.StatusPending, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []actionengine.Action
	for rows.Next() {
		a, err := scanActionRow(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *a)
	}
	return out, rows.Err()
}

func (r *ActionRepository) MarkRejected(ctx context.Context, userID, actionID string) (*actionengine.Action, error) {
	const q = `
		UPDATE ai_actions
		SET status = $3, resolved_at = NOW()
		WHERE id = $1::uuid AND user_id = $2::uuid AND status = $4
		RETURNING id::text, user_id::text, insight_id::text,
			source_type, source_id::text, action_type, target_type, target_id::text,
			COALESCE(payload, '{}'::jsonb), reason, status, created_at, resolved_at, applied_at`
	row := r.pool.QueryRow(ctx, q, actionID, userID, actionengine.StatusRejected, actionengine.StatusPending)
	a, err := scanActionRow(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrActionNotPending
		}
		return nil, err
	}
	return a, nil
}

func (r *ActionRepository) MarkApplied(ctx context.Context, userID, actionID string) (*actionengine.Action, error) {
	const q = `
		UPDATE ai_actions
		SET status = $3, applied_at = NOW(), resolved_at = NOW()
		WHERE id = $1::uuid AND user_id = $2::uuid AND status = $4
		RETURNING id::text, user_id::text, insight_id::text,
			source_type, source_id::text, action_type, target_type, target_id::text,
			COALESCE(payload, '{}'::jsonb), reason, status, created_at, resolved_at, applied_at`
	row := r.pool.QueryRow(ctx, q, actionID, userID, actionengine.StatusApplied, actionengine.StatusPending)
	a, err := scanActionRow(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrActionNotPending
		}
		return nil, err
	}
	return a, nil
}

func (r *ActionRepository) RejectPendingBySource(ctx context.Context, userID, sourceType, sourceID string) error {
	_, err := r.pool.Exec(ctx, `
		UPDATE ai_actions
		SET status = $4, resolved_at = NOW()
		WHERE user_id = $1::uuid AND source_type = $2 AND source_id = $3::uuid AND status = $5`,
		userID, sourceType, sourceID, actionengine.StatusRejected, actionengine.StatusPending)
	return err
}

type scannable interface {
	Scan(dest ...any) error
}

func scanActionRow(row scannable) (*actionengine.Action, error) {
	var a actionengine.Action
	var iid, srcType, srcID, tgtType, tgtID, reason sql.NullString
	var res, applied sql.NullTime
	if err := row.Scan(
		&a.ID, &a.UserID, &iid,
		&srcType, &srcID, &a.ActionType, &tgtType, &tgtID,
		&a.Payload, &reason, &a.Status, &a.CreatedAt, &res, &applied,
	); err != nil {
		return nil, err
	}
	if iid.Valid {
		s := iid.String
		a.InsightID = &s
	}
	if srcType.Valid {
		s := srcType.String
		a.SourceType = &s
	}
	if srcID.Valid {
		s := srcID.String
		a.SourceID = &s
	}
	if tgtType.Valid {
		s := tgtType.String
		a.TargetType = &s
	}
	if tgtID.Valid {
		s := tgtID.String
		a.TargetID = &s
	}
	if reason.Valid {
		s := reason.String
		a.Reason = &s
	}
	if res.Valid {
		t := res.Time
		a.ResolvedAt = &t
	}
	if applied.Valid {
		t := applied.Time
		a.AppliedAt = &t
	}
	return &a, nil
}
