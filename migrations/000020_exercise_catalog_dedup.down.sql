-- Irreversible data merge: re-seed removed names if missing (ids will differ from pre-up).

INSERT INTO exercises (name, muscle_group, equipment, is_custom, created_by)
SELECT 'Row', 'back', 'cable', FALSE, NULL
WHERE NOT EXISTS (
    SELECT 1 FROM exercises WHERE name = 'Row' AND is_custom = FALSE AND created_by IS NULL
);

INSERT INTO exercises (name, muscle_group, equipment, is_custom, created_by)
SELECT 'Overhead Press', 'shoulders', 'barbell', FALSE, NULL
WHERE NOT EXISTS (
    SELECT 1 FROM exercises WHERE name = 'Overhead Press' AND is_custom = FALSE AND created_by IS NULL
);
