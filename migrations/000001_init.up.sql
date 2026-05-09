-- users: account + auth
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT,
    auth_provider TEXT NOT NULL DEFAULT 'email',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- profiles: 1:1 with users, holds fitness/demographic info
CREATE TABLE profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    age INT,
    weight_kg NUMERIC(5,2),
    height_cm NUMERIC(5,2),
    gender TEXT,
    fitness_goal TEXT,
    training_experience TEXT,
    preferred_split TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- exercises: shared catalog + user-created custom exercises
CREATE TABLE exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    muscle_group TEXT,
    equipment TEXT,
    is_custom BOOLEAN NOT NULL DEFAULT FALSE,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_exercises_muscle_group ON exercises(muscle_group);
CREATE INDEX idx_exercises_created_by ON exercises(created_by);

-- routines: saved workout templates
CREATE TABLE routines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_routines_user_id ON routines(user_id);

-- routine_exercises: ordered exercises inside a routine
CREATE TABLE routine_exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    routine_id UUID NOT NULL REFERENCES routines(id) ON DELETE CASCADE,
    exercise_id UUID NOT NULL REFERENCES exercises(id),
    position INT NOT NULL,
    target_sets INT,
    target_reps INT,
    target_weight_kg NUMERIC(6,2),
    notes TEXT,
    UNIQUE (routine_id, position)
);
CREATE INDEX idx_routine_exercises_routine_id ON routine_exercises(routine_id);

-- workouts: a single training session
CREATE TABLE workouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    routine_id UUID REFERENCES routines(id) ON DELETE SET NULL,
    name TEXT,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_workouts_user_id ON workouts(user_id);
CREATE INDEX idx_workouts_started_at ON workouts(user_id, started_at DESC);

-- workout_sets: each logged set inside a workout
CREATE TABLE workout_sets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workout_id UUID NOT NULL REFERENCES workouts(id) ON DELETE CASCADE,
    exercise_id UUID NOT NULL REFERENCES exercises(id),
    set_number INT NOT NULL,
    reps INT,
    weight_kg NUMERIC(6,2),
    rpe NUMERIC(3,1),
    is_failure BOOLEAN NOT NULL DEFAULT FALSE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_workout_sets_workout_id ON workout_sets(workout_id);
CREATE INDEX idx_workout_sets_exercise_id ON workout_sets(exercise_id);

-- recovery_checkins: daily lifestyle/recovery signal
CREATE TABLE recovery_checkins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    checkin_date DATE NOT NULL,
    sleep_score INT,
    energy_score INT,
    soreness_score INT,
    stress_score INT,
    hydration_score INT,
    calorie_estimate INT,
    protein_estimate INT,
    raw_voice_input TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, checkin_date)
);
CREATE INDEX idx_recovery_checkins_user_date ON recovery_checkins(user_id, checkin_date DESC);

-- ai_insights: LLM-generated coaching feedback tied to a workout or window
CREATE TABLE ai_insights (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    workout_id UUID REFERENCES workouts(id) ON DELETE CASCADE,
    insight_type TEXT NOT NULL,
    generated_text TEXT NOT NULL,
    metrics JSONB,
    model TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_ai_insights_user_id ON ai_insights(user_id, created_at DESC);
CREATE INDEX idx_ai_insights_workout_id ON ai_insights(workout_id);

-- ai_actions: structured recommendations the action engine surfaces to the user
CREATE TABLE ai_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    insight_id UUID REFERENCES ai_insights(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL,
    payload JSONB,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);
CREATE INDEX idx_ai_actions_user_id ON ai_actions(user_id, status);
CREATE INDEX idx_ai_actions_insight_id ON ai_actions(insight_id);
