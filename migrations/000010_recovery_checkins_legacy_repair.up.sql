-- Fix drift: schema_migrations can show 8/9 applied while table still matches 000001
-- (wrong DATABASE_URL, or `force` without re-running SQL). Recreate table only if legacy columns exist.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'recovery_checkins'
          AND column_name = 'sleep_score'
    ) THEN
        DROP TABLE recovery_checkins CASCADE;
        CREATE TABLE recovery_checkins (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            checkin_date DATE NOT NULL,
            sleep_hours NUMERIC(4,1) NOT NULL CHECK (sleep_hours >= 0 AND sleep_hours <= 24),
            energy_readiness SMALLINT NOT NULL CHECK (energy_readiness >= 1 AND energy_readiness <= 5),
            calories_kcal INT NOT NULL CHECK (calories_kcal >= 0 AND calories_kcal <= 20000),
            protein_g INT NOT NULL CHECK (protein_g >= 0 AND protein_g <= 800),
            notes TEXT,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            UNIQUE (user_id, checkin_date)
        );
        CREATE INDEX idx_recovery_checkins_user_date ON recovery_checkins (user_id, checkin_date DESC);
    END IF;
END $$;
