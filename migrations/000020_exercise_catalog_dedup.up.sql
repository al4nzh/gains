-- Deduplicate system catalog exercises that conflict with ExerciseDB matching and each other.
-- "Row" duplicates "Cable Row"; "Overhead Press" duplicates "OHP".

DO $$
DECLARE
    row_id UUID;
    cable_row_id UUID;
    ohp_id UUID;
    overhead_id UUID;
BEGIN
    SELECT id INTO row_id FROM exercises
        WHERE name = 'Row' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
    SELECT id INTO cable_row_id FROM exercises
        WHERE name = 'Cable Row' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
    SELECT id INTO ohp_id FROM exercises
        WHERE name = 'OHP' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;
    SELECT id INTO overhead_id FROM exercises
        WHERE name = 'Overhead Press' AND is_custom = FALSE AND created_by IS NULL LIMIT 1;

    IF row_id IS NOT NULL AND cable_row_id IS NOT NULL AND row_id <> cable_row_id THEN
        UPDATE routine_exercises SET exercise_id = cable_row_id WHERE exercise_id = row_id;
        UPDATE routine_template_exercises SET exercise_id = cable_row_id WHERE exercise_id = row_id;
        UPDATE workout_sets SET exercise_id = cable_row_id WHERE exercise_id = row_id;
        DELETE FROM exercises WHERE id = row_id;
    END IF;

    IF ohp_id IS NOT NULL AND overhead_id IS NOT NULL AND ohp_id <> overhead_id THEN
        UPDATE routine_exercises SET exercise_id = ohp_id WHERE exercise_id = overhead_id;
        UPDATE routine_template_exercises SET exercise_id = ohp_id WHERE exercise_id = overhead_id;
        UPDATE workout_sets SET exercise_id = ohp_id WHERE exercise_id = overhead_id;
        DELETE FROM exercises WHERE id = overhead_id;
    END IF;
END $$;
