-- One saved post-workout analysis per workout; optional human-readable title.
ALTER TABLE ai_insights
    ADD COLUMN IF NOT EXISTS title TEXT NOT NULL DEFAULT 'Workout analysis';

-- Deduplicate by workout_id (keep newest) before adding UNIQUE(workout_id).
DELETE FROM ai_insights a
    USING ai_insights b
WHERE a.workout_id IS NOT NULL
  AND a.workout_id = b.workout_id
  AND a.id <> b.id
  AND a.created_at < b.created_at;

-- At most one insight row per workout_id (NULL workout_id still allowed multiple times for other insight kinds).
ALTER TABLE ai_insights
    ADD CONSTRAINT ai_insights_workout_id_unique UNIQUE (workout_id);
