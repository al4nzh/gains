-- At most one in-progress workout per user (completed_at IS NULL).
-- Drop duplicate active rows (keep newest started_at per user) before adding the index.
DELETE FROM workouts w
USING (
    SELECT id
    FROM (
        SELECT id,
            ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY started_at DESC) AS rn
        FROM workouts
        WHERE completed_at IS NULL
    ) ranked
    WHERE rn > 1
) dup
WHERE w.id = dup.id;

CREATE UNIQUE INDEX idx_workouts_one_active_per_user ON workouts (user_id)
    WHERE completed_at IS NULL;
