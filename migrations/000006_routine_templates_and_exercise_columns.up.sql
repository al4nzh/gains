-- routine_exercises: rep range, RPE, rest (migrate from target_reps)
ALTER TABLE routine_exercises
    ADD COLUMN IF NOT EXISTS target_rep_min INT,
    ADD COLUMN IF NOT EXISTS target_rep_max INT,
    ADD COLUMN IF NOT EXISTS target_rpe NUMERIC(3,1),
    ADD COLUMN IF NOT EXISTS rest_seconds INT;

UPDATE routine_exercises
SET target_rep_min = target_reps, target_rep_max = target_reps
WHERE target_reps IS NOT NULL AND (target_rep_min IS NULL AND target_rep_max IS NULL);

ALTER TABLE routine_exercises DROP COLUMN IF EXISTS target_reps;

-- Global routine templates (no user_id)
CREATE TABLE routine_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE routine_template_exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id UUID NOT NULL REFERENCES routine_templates(id) ON DELETE CASCADE,
    exercise_id UUID NOT NULL REFERENCES exercises(id),
    position INT NOT NULL,
    target_sets INT,
    target_rep_min INT,
    target_rep_max INT,
    target_rpe NUMERIC(3,1),
    rest_seconds INT,
    notes TEXT,
    UNIQUE (template_id, position)
);
CREATE INDEX idx_routine_template_exercises_template_id ON routine_template_exercises(template_id);

-- Seed global templates (requires catalog exercises from 000004)
INSERT INTO routine_templates (id, name, description) VALUES
('b0000000-0000-4000-8000-000000000001'::uuid, 'Beginner Full Body', 'A simple starter template covering major movement patterns.'),
('b0000000-0000-4000-8000-000000000002'::uuid, 'Push Day', 'Chest, shoulders, and triceps emphasis.'),
('b0000000-0000-4000-8000-000000000003'::uuid, 'Pull Day', 'Back and biceps emphasis.'),
('b0000000-0000-4000-8000-000000000004'::uuid, 'Legs', 'Lower-body focused session.');

INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000001'::uuid, id, 1, 3, 8, 12, NULL, 120, NULL FROM exercises WHERE name = 'Squat' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000001'::uuid, id, 2, 3, 8, 12, NULL, 120, NULL FROM exercises WHERE name = 'Bench Press' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000001'::uuid, id, 3, 3, 6, 10, NULL, 150, NULL FROM exercises WHERE name = 'Deadlift' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000001'::uuid, id, 4, 3, 10, 15, NULL, 90, NULL FROM exercises WHERE name = 'Lat Pulldown' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000001'::uuid, id, 5, 3, 6, 10, NULL, 120, NULL FROM exercises WHERE name = 'OHP' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000001'::uuid, id, 6, 3, 45, 60, NULL, 60, 'seconds hold or reps as preferred' FROM exercises WHERE name = 'Plank' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;

INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000002'::uuid, id, 1, 4, 6, 10, NULL, 150, NULL FROM exercises WHERE name = 'Bench Press' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000002'::uuid, id, 2, 3, 8, 12, NULL, 120, NULL FROM exercises WHERE name = 'Incline DB Press' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000002'::uuid, id, 3, 3, 8, 12, NULL, 90, NULL FROM exercises WHERE name = 'Dumbbell Bench Press' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000002'::uuid, id, 4, 3, 6, 10, NULL, 120, NULL FROM exercises WHERE name = 'OHP' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000002'::uuid, id, 5, 3, 8, 15, NULL, 90, NULL FROM exercises WHERE name = 'Dip' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000002'::uuid, id, 6, 3, 10, 15, NULL, 60, NULL FROM exercises WHERE name = 'Triceps Pushdown' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000002'::uuid, id, 7, 3, 12, 20, NULL, 60, NULL FROM exercises WHERE name = 'Lateral Raise' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;

INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000003'::uuid, id, 1, 3, 5, 8, NULL, 180, NULL FROM exercises WHERE name = 'Deadlift' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000003'::uuid, id, 2, 4, 5, 12, NULL, 120, NULL FROM exercises WHERE name = 'Pull Up' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000003'::uuid, id, 3, 3, 10, 15, NULL, 90, NULL FROM exercises WHERE name = 'Lat Pulldown' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000003'::uuid, id, 4, 4, 6, 10, NULL, 120, NULL FROM exercises WHERE name = 'Barbell Row' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000003'::uuid, id, 5, 3, 12, 20, NULL, 60, NULL FROM exercises WHERE name = 'Face Pull' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000003'::uuid, id, 6, 3, 10, 15, NULL, 60, NULL FROM exercises WHERE name = 'Hammer Curl' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;

INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000004'::uuid, id, 1, 4, 5, 8, NULL, 180, NULL FROM exercises WHERE name = 'Squat' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000004'::uuid, id, 2, 3, 10, 15, NULL, 120, NULL FROM exercises WHERE name = 'Leg Press' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000004'::uuid, id, 3, 3, 8, 12, NULL, 120, NULL FROM exercises WHERE name = 'Romanian Deadlift' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000004'::uuid, id, 4, 3, 10, 15, NULL, 90, NULL FROM exercises WHERE name = 'Leg Curl' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000004'::uuid, id, 5, 3, 12, 20, NULL, 75, NULL FROM exercises WHERE name = 'Leg Extension' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000004'::uuid, id, 6, 4, 12, 20, NULL, 60, NULL FROM exercises WHERE name = 'Calf Raise' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
