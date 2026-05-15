ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_activity_level_chk;
ALTER TABLE profiles DROP COLUMN IF EXISTS activity_level;
