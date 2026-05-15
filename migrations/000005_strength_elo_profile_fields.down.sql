ALTER TABLE profiles
    DROP COLUMN IF EXISTS last_strength_elo_update,
    DROP COLUMN IF EXISTS strength_elo_change_30d,
    DROP COLUMN IF EXISTS strength_elo_rank,
    DROP COLUMN IF EXISTS strength_elo;

