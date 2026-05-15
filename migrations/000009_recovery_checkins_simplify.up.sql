-- Simplify recovery check-ins: sleep hours + readiness + macros + optional note
ALTER TABLE recovery_checkins
    ADD COLUMN energy_readiness SMALLINT NOT NULL DEFAULT 3,
    ADD COLUMN protein_g INT NOT NULL DEFAULT 0;

UPDATE recovery_checkins SET sleep_hours = COALESCE(sleep_hours, 7.0) WHERE sleep_hours IS NULL;

ALTER TABLE recovery_checkins ALTER COLUMN sleep_hours SET NOT NULL;

ALTER TABLE recovery_checkins DROP COLUMN IF EXISTS sleep_quality;
ALTER TABLE recovery_checkins DROP COLUMN IF EXISTS tags;

ALTER TABLE recovery_checkins ALTER COLUMN energy_readiness DROP DEFAULT;
ALTER TABLE recovery_checkins ALTER COLUMN protein_g DROP DEFAULT;

ALTER TABLE recovery_checkins DROP CONSTRAINT IF EXISTS recovery_checkins_sleep_hours_check;
ALTER TABLE recovery_checkins ADD CONSTRAINT recovery_checkins_sleep_hours_chk
    CHECK (sleep_hours >= 0 AND sleep_hours <= 24);

ALTER TABLE recovery_checkins ADD CONSTRAINT recovery_checkins_energy_readiness_chk
    CHECK (energy_readiness >= 1 AND energy_readiness <= 5);

ALTER TABLE recovery_checkins ADD CONSTRAINT recovery_checkins_protein_g_chk
    CHECK (protein_g >= 0 AND protein_g <= 800);
