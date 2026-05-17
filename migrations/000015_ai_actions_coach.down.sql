DROP INDEX IF EXISTS idx_ai_actions_target;
DROP INDEX IF EXISTS idx_ai_actions_source;

ALTER TABLE ai_actions
    DROP COLUMN IF EXISTS applied_at,
    DROP COLUMN IF EXISTS reason,
    DROP COLUMN IF EXISTS target_id,
    DROP COLUMN IF EXISTS target_type,
    DROP COLUMN IF EXISTS source_id,
    DROP COLUMN IF EXISTS source_type;
