-- Expand system catalog (non-custom) with common lifts.
-- Insert only if a system exercise with the same name doesn't already exist.

WITH new_exercises (name, muscle_group, equipment) AS (
  VALUES
    -- Chest
    ('Decline Bench Press', 'chest', 'barbell'),
    ('Machine Chest Press', 'chest', 'machine'),
    ('Dumbbell Fly', 'chest', 'dumbbell'),

    -- Back
    ('Straight-Arm Pulldown', 'back', 'cable'),
    ('Machine Pulldown', 'back', 'machine'),
    ('Shrug', 'back', 'dumbbell'),

    -- Legs / Glutes
    ('Hack Squat', 'legs', 'machine'),
    ('Smith Squat', 'legs', 'machine'),
    ('Goblet Squat', 'legs', 'dumbbell'),
    ('Good Morning', 'legs', 'barbell'),
    ('Glute Bridge', 'legs', 'barbell'),
    ('Step Up', 'legs', 'dumbbell'),
    ('Seated Leg Curl', 'legs', 'machine'),
    ('Seated Calf Raise', 'legs', 'machine'),
    ('Standing Calf Raise', 'legs', 'machine'),

    -- Shoulders
    ('Machine Shoulder Press', 'shoulders', 'machine'),
    ('Cable Lateral Raise', 'shoulders', 'cable'),
    ('Upright Row', 'shoulders', 'barbell'),

    -- Arms
    ('EZ Bar Curl', 'arms', 'barbell'),
    ('Cable Curl', 'arms', 'cable'),
    ('Incline DB Curl', 'arms', 'dumbbell'),
    ('Rope Triceps Pushdown', 'arms', 'cable'),
    ('Cable Overhead Triceps Extension', 'arms', 'cable'),

    -- Core
    ('Russian Twist', 'core', 'bodyweight'),
    ('Side Plank', 'core', 'bodyweight')
)
INSERT INTO exercises (name, muscle_group, equipment, is_custom, created_by)
SELECT n.name, n.muscle_group, n.equipment, FALSE, NULL
FROM new_exercises n
WHERE NOT EXISTS (
  SELECT 1
  FROM exercises e
  WHERE e.is_custom = FALSE
    AND lower(e.name) = lower(n.name)
);

