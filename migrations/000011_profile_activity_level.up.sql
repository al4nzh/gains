-- Lifestyle activity (outside gym) for nutrition / analytics targets
ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS activity_level TEXT;

ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_activity_level_chk;
ALTER TABLE profiles ADD CONSTRAINT profiles_activity_level_chk
    CHECK (
        activity_level IS NULL
        OR activity_level IN ('sedentary', 'light', 'moderate', 'active', 'very_active')
    );
