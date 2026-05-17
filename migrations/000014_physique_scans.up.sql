CREATE TABLE physique_scans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    estimated_body_fat_pct INT NOT NULL CHECK (estimated_body_fat_pct >= 1 AND estimated_body_fat_pct <= 70),
    confidence TEXT NOT NULL CHECK (confidence IN ('low', 'medium', 'high')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_physique_scans_user_created ON physique_scans(user_id, created_at DESC);
