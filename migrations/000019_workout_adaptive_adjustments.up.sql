ALTER TABLE workouts
    ADD COLUMN IF NOT EXISTS adaptive_adjustments JSONB NOT NULL DEFAULT '[]'::jsonb;
