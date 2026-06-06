ALTER TABLE users ADD COLUMN is_premium BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE ai_daily_usage (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    usage_date DATE NOT NULL DEFAULT CURRENT_DATE,
    coach_messages INT NOT NULL DEFAULT 0,
    workout_analyses INT NOT NULL DEFAULT 0,
    routine_generations INT NOT NULL DEFAULT 0,
    physique_scans INT NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, usage_date)
);

CREATE INDEX idx_ai_daily_usage_date ON ai_daily_usage (usage_date);
