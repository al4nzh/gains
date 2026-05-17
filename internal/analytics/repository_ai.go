package analytics

import (
	"context"
	"database/sql"

	"gainsai/internal/actionengine"
)

// ListPendingAIActions returns pending AI actions for a user.
func (r *Repository) ListPendingAIActions(ctx context.Context, userID string, limit int) ([]actionengine.Action, error) {
	if limit < 1 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
	rows, err := r.pool.Query(ctx, `
		SELECT id::text, user_id::text, insight_id::text,
			source_type, source_id::text, action_type, target_type, target_id::text,
			COALESCE(payload, '{}'::jsonb), reason, status, created_at, resolved_at, applied_at
		FROM ai_actions
		WHERE user_id = $1 AND status = $2
		ORDER BY created_at DESC
		LIMIT $3`, userID, actionengine.StatusPending, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []actionengine.Action
	for rows.Next() {
		a, err := scanAIAction(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

func scanAIAction(row interface {
	Scan(dest ...any) error
}) (actionengine.Action, error) {
	var a actionengine.Action
	var iid, srcType, srcID, tgtType, tgtID, reason sql.NullString
	var res, applied sql.NullTime
	if err := row.Scan(
		&a.ID, &a.UserID, &iid,
		&srcType, &srcID, &a.ActionType, &tgtType, &tgtID,
		&a.Payload, &reason, &a.Status, &a.CreatedAt, &res, &applied,
	); err != nil {
		return a, err
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
	return a, nil
}
