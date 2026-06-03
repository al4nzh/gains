-- Additional global routine templates (catalog exercises from 000004).

INSERT INTO routine_templates (id, name, description) VALUES
('b0000000-0000-4000-8000-000000000005'::uuid, 'Upper Body A',
 'Horizontal push/pull focus. Pair with Lower Body A for a 4-day upper/lower split.'),
('b0000000-0000-4000-8000-000000000006'::uuid, 'Lower Body A',
 'Squat-pattern lower day. Pair with Upper Body A.'),
('b0000000-0000-4000-8000-000000000007'::uuid, 'Upper Body B',
 'Incline pressing and vertical pull emphasis. Pair with Lower Body B.'),
('b0000000-0000-4000-8000-000000000008'::uuid, 'Lower Body B',
 'Hinge and single-leg focus. Pair with Upper Body B.'),
('b0000000-0000-4000-8000-000000000009'::uuid, 'Strength 5×5',
 'Classic heavy compounds: squat, bench, row, press, and a single top deadlift set.'),
('b0000000-0000-4000-8000-00000000000a'::uuid, 'Full Body Hypertrophy',
 'Three-day full body with moderate volume. Good default for muscle gain.'),
('b0000000-0000-4000-8000-00000000000b'::uuid, 'Home / Minimal Equipment',
 'Push, pull, and legs with little or no barbell. Dumbbells + bodyweight friendly.'),
('b0000000-0000-4000-8000-00000000000c'::uuid, 'Arms & Core',
 'Accessory session for bis, tris, and abs. Stack after upper/lower or PPL days.');

-- Upper Body A
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000005'::uuid, id, 1, 4, 6, 8, NULL, 150, NULL FROM exercises WHERE name = 'Bench Press' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000005'::uuid, id, 2, 4, 6, 10, NULL, 120, NULL FROM exercises WHERE name = 'Barbell Row' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000005'::uuid, id, 3, 3, 6, 10, NULL, 120, NULL FROM exercises WHERE name = 'OHP' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000005'::uuid, id, 4, 3, 10, 12, NULL, 90, NULL FROM exercises WHERE name = 'Lat Pulldown' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000005'::uuid, id, 5, 3, 12, 15, NULL, 60, NULL FROM exercises WHERE name = 'Lateral Raise' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000005'::uuid, id, 6, 3, 10, 15, NULL, 60, NULL FROM exercises WHERE name = 'Triceps Pushdown' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000005'::uuid, id, 7, 3, 10, 12, NULL, 60, NULL FROM exercises WHERE name = 'Hammer Curl' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;

-- Lower Body A
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000006'::uuid, id, 1, 4, 5, 8, NULL, 180, NULL FROM exercises WHERE name = 'Squat' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000006'::uuid, id, 2, 3, 8, 12, NULL, 120, NULL FROM exercises WHERE name = 'Romanian Deadlift' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000006'::uuid, id, 3, 3, 10, 15, NULL, 90, NULL FROM exercises WHERE name = 'Leg Press' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000006'::uuid, id, 4, 3, 10, 15, NULL, 75, NULL FROM exercises WHERE name = 'Leg Curl' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000006'::uuid, id, 5, 3, 12, 15, NULL, 60, NULL FROM exercises WHERE name = 'Leg Extension' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000006'::uuid, id, 6, 4, 12, 20, NULL, 60, NULL FROM exercises WHERE name = 'Calf Raise' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;

-- Upper Body B
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000007'::uuid, id, 1, 4, 6, 10, NULL, 120, NULL FROM exercises WHERE name = 'Incline Bench Press' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000007'::uuid, id, 2, 3, 6, 12, NULL, 120, 'Add weight or band if needed' FROM exercises WHERE name = 'Chin Up' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000007'::uuid, id, 3, 3, 8, 12, NULL, 90, NULL FROM exercises WHERE name = 'Dumbbell Shoulder Press' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000007'::uuid, id, 4, 3, 10, 12, NULL, 90, NULL FROM exercises WHERE name = 'Cable Row' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000007'::uuid, id, 5, 3, 15, 20, NULL, 60, NULL FROM exercises WHERE name = 'Face Pull' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000007'::uuid, id, 6, 3, 8, 12, NULL, 120, NULL FROM exercises WHERE name = 'Close Grip Bench Press' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000007'::uuid, id, 7, 3, 8, 12, NULL, 60, NULL FROM exercises WHERE name = 'Barbell Curl' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;

-- Lower Body B
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000008'::uuid, id, 1, 3, 6, 10, NULL, 150, NULL FROM exercises WHERE name = 'Front Squat' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000008'::uuid, id, 2, 4, 8, 12, NULL, 90, NULL FROM exercises WHERE name = 'Hip Thrust' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000008'::uuid, id, 3, 3, 8, 12, NULL, 90, 'Per leg' FROM exercises WHERE name = 'Bulgarian Split Squat' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000008'::uuid, id, 4, 3, 10, 15, NULL, 75, NULL FROM exercises WHERE name = 'Leg Curl' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000008'::uuid, id, 5, 3, 10, 12, NULL, 90, 'Per leg' FROM exercises WHERE name = 'Walking Lunge' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000008'::uuid, id, 6, 4, 15, 20, NULL, 60, NULL FROM exercises WHERE name = 'Calf Raise' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;

-- Strength 5×5
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000009'::uuid, id, 1, 5, 5, 5, NULL, 180, 'Add weight when all sets are clean' FROM exercises WHERE name = 'Squat' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000009'::uuid, id, 2, 5, 5, 5, NULL, 180, NULL FROM exercises WHERE name = 'Bench Press' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000009'::uuid, id, 3, 5, 5, 5, NULL, 150, NULL FROM exercises WHERE name = 'Barbell Row' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000009'::uuid, id, 4, 3, 8, 8, NULL, 120, NULL FROM exercises WHERE name = 'OHP' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-000000000009'::uuid, id, 5, 1, 5, 5, NULL, 180, 'One heavy set; skip if fatigued' FROM exercises WHERE name = 'Deadlift' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;

-- Full Body Hypertrophy
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-00000000000a'::uuid, id, 1, 3, 8, 12, NULL, 120, NULL FROM exercises WHERE name = 'Squat' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-00000000000a'::uuid, id, 2, 3, 8, 12, NULL, 120, NULL FROM exercises WHERE name = 'Bench Press' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-00000000000a'::uuid, id, 3, 3, 8, 12, NULL, 120, NULL FROM exercises WHERE name = 'Romanian Deadlift' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-00000000000a'::uuid, id, 4, 3, 10, 15, NULL, 90, NULL FROM exercises WHERE name = 'Lat Pulldown' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-00000000000a'::uuid, id, 5, 3, 8, 12, NULL, 90, NULL FROM exercises WHERE name = 'Dumbbell Shoulder Press' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-00000000000a'::uuid, id, 6, 3, 45, 60, NULL, 60, 'seconds hold or reps as preferred' FROM exercises WHERE name = 'Plank' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;

-- Home / Minimal Equipment
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-00000000000b'::uuid, id, 1, 3, 10, 20, NULL, 75, NULL FROM exercises WHERE name = 'Push Up' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-00000000000b'::uuid, id, 2, 3, 5, 12, NULL, 120, 'Use band assist if needed' FROM exercises WHERE name = 'Pull Up' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-00000000000b'::uuid, id, 3, 3, 8, 12, NULL, 90, 'Per leg' FROM exercises WHERE name = 'Bulgarian Split Squat' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-00000000000b'::uuid, id, 4, 3, 10, 12, NULL, 90, NULL FROM exercises WHERE name = 'Dumbbell Row' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-00000000000b'::uuid, id, 5, 3, 8, 15, NULL, 90, NULL FROM exercises WHERE name = 'Dip' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-00000000000b'::uuid, id, 6, 3, 45, 60, NULL, 60, 'seconds hold or reps as preferred' FROM exercises WHERE name = 'Plank' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;

-- Arms & Core
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-00000000000c'::uuid, id, 1, 3, 8, 12, NULL, 120, NULL FROM exercises WHERE name = 'Close Grip Bench Press' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-00000000000c'::uuid, id, 2, 3, 8, 12, NULL, 90, NULL FROM exercises WHERE name = 'Skull Crusher' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-00000000000c'::uuid, id, 3, 3, 12, 15, NULL, 60, NULL FROM exercises WHERE name = 'Triceps Pushdown' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-00000000000c'::uuid, id, 4, 3, 8, 12, NULL, 60, NULL FROM exercises WHERE name = 'Barbell Curl' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-00000000000c'::uuid, id, 5, 3, 10, 12, NULL, 60, NULL FROM exercises WHERE name = 'Hammer Curl' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-00000000000c'::uuid, id, 6, 3, 10, 12, NULL, 60, NULL FROM exercises WHERE name = 'Preacher Curl' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-00000000000c'::uuid, id, 7, 3, 12, 20, NULL, 60, NULL FROM exercises WHERE name = 'Cable Crunch' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
INSERT INTO routine_template_exercises (template_id, exercise_id, position, target_sets, target_rep_min, target_rep_max, target_rpe, rest_seconds, notes)
SELECT 'b0000000-0000-4000-8000-00000000000c'::uuid, id, 8, 3, 10, 15, NULL, 60, NULL FROM exercises WHERE name = 'Hanging Leg Raise' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
