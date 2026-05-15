ALTER TABLE recovery_checkins DROP CONSTRAINT IF EXISTS recovery_checkins_sleep_hours_chk;
ALTER TABLE recovery_checkins DROP CONSTRAINT IF EXISTS recovery_checkins_energy_readiness_chk;
ALTER TABLE recovery_checkins DROP CONSTRAINT IF EXISTS recovery_checkins_protein_g_chk;

ALTER TABLE recovery_checkins DROP COLUMN IF EXISTS energy_readiness;
ALTER TABLE recovery_checkins DROP COLUMN IF EXISTS protein_g;

ALTER TABLE recovery_checkins ADD COLUMN sleep_quality SMALLINT NOT NULL DEFAULT 3;
ALTER TABLE recovery_checkins ADD COLUMN tags JSONB NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE recovery_checkins ALTER COLUMN sleep_hours DROP NOT NULL;

ALTER TABLE recovery_checkins ADD CONSTRAINT recovery_checkins_sleep_hours_legacy_chk
    CHECK (sleep_hours IS NULL OR (sleep_hours >= 0 AND sleep_hours <= 24));

ALTER TABLE recovery_checkins ADD CONSTRAINT recovery_checkins_sleep_quality_legacy_chk
    CHECK (sleep_quality >= 1 AND sleep_quality <= 5);

ALTER TABLE recovery_checkins ALTER COLUMN sleep_quality DROP DEFAULT;
