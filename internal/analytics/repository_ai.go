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
		SELECT id::text, user_id::text, insight_id::text, action_type, COALESCE(payload, '{}'::jsonb), status, created_at, resolved_at
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
		var a actionengine.Action
		var iid sql.NullString
		var res sql.NullTime
		if err := rows.Scan(&a.ID, &a.UserID, &iid, &a.ActionType, &a.Payload, &a.Status, &a.CreatedAt, &res); err != nil {
			return nil, err
		}
		if iid.Valid {
			s := iid.String
			a.InsightID = &s
		}
		if res.Valid {
			t := res.Time
			a.ResolvedAt = &t
		}
		out = append(out, a)
	}
	return out, rows.Err()
}
