DROP TABLE IF EXISTS strength_elo_history;

ALTER TABLE workouts
    DROP COLUMN IF EXISTS stats,
    DROP COLUMN IF EXISTS duration_seconds,
    DROP COLUMN IF EXISTS total_volume_kg;
