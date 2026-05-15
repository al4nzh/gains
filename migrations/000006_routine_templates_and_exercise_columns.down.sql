DROP TABLE IF EXISTS routine_template_exercises;
DROP TABLE IF EXISTS routine_templates;

ALTER TABLE routine_exercises
    ADD COLUMN IF NOT EXISTS target_reps INT;

UPDATE routine_exercises
SET target_reps = COALESCE(target_rep_min, target_rep_max)
WHERE target_reps IS NULL AND (target_rep_min IS NOT NULL OR target_rep_max IS NOT NULL);

ALTER TABLE routine_exercises
    DROP COLUMN IF EXISTS rest_seconds,
    DROP COLUMN IF EXISTS target_rpe,
    DROP COLUMN IF EXISTS target_rep_max,
    DROP COLUMN IF EXISTS target_rep_min;
