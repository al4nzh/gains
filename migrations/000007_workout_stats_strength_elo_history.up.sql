-- Persisted workout summary (filled on finish)
ALTER TABLE workouts
    ADD COLUMN IF NOT EXISTS total_volume_kg NUMERIC(14, 2),
    ADD COLUMN IF NOT EXISTS duration_seconds INT,
    ADD COLUMN IF NOT EXISTS stats JSONB;

-- Strength Elo audit trail (one row per finished workout that applied an Elo update)
CREATE TABLE strength_elo_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    workout_id UUID REFERENCES workouts(id) ON DELETE SET NULL,
    elo_before INT NOT NULL,
    elo_after INT NOT NULL,
    delta INT NOT NULL,
    bodyweight_kg NUMERIC(6, 2),
    session_score NUMERIC(10, 4),
    meta JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_strength_elo_history_user_created ON strength_elo_history(user_id, created_at DESC);
CREATE INDEX idx_strength_elo_history_workout_id ON strength_elo_history(workout_id);
