-- Daily recovery check-ins (replaces legacy recovery_checkins from 000001 if present)
DROP TABLE IF EXISTS recovery_checkins;

CREATE TABLE recovery_checkins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    checkin_date DATE NOT NULL,
    sleep_quality SMALLINT NOT NULL CHECK (sleep_quality >= 1 AND sleep_quality <= 5),
    sleep_hours NUMERIC(4,1) CHECK (sleep_hours IS NULL OR (sleep_hours >= 0 AND sleep_hours <= 24)),
    calories_kcal INT NOT NULL CHECK (calories_kcal >= 0 AND calories_kcal <= 20000),
    tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, checkin_date)
);

CREATE INDEX idx_recovery_checkins_user_date ON recovery_checkins (user_id, checkin_date DESC);
