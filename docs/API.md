# Gains API

HTTP API for the Gains backend (Gin). Base URL defaults to `http://localhost:{PORT}` (`PORT` from env, default **8080**).

## Conventions

| Item | Behavior |
|------|----------|
| **Content-Type** | `application/json` on request bodies |
| **Auth** | `Authorization: Bearer <access_token>` where marked **Auth: required** |
| **IDs** | UUID strings |
| **Errors** | JSON `{ "error": "..." }` (health may include `status`, `db`) |
| **Rate limits** | Per client IP (token bucket). **429** `{ "error": "rate limit exceeded" }` |

### Rate limit environment variables

| Scope | Variables | Defaults |
|-------|-----------|------------|
| `/auth/*` | `AUTH_RATE_LIMIT_RPS`, `AUTH_RATE_LIMIT_BURST` | 5, 10 |
| `/profile` | `PROFILE_RATE_LIMIT_RPS`, `PROFILE_RATE_LIMIT_BURST` | 10, 20 |
| `/exercises` | `EXERCISE_RATE_LIMIT_RPS`, `EXERCISE_RATE_LIMIT_BURST` | 20, 40 |
| `/routines`, `/routine-templates` | `ROUTINE_RATE_LIMIT_RPS`, `ROUTINE_RATE_LIMIT_BURST` | 15, 30 |
| `/workouts` | `WORKOUT_RATE_LIMIT_RPS`, `WORKOUT_RATE_LIMIT_BURST` | 25, 50 |
| `/recovery-checkins` | `RECOVERY_RATE_LIMIT_RPS`, `RECOVERY_RATE_LIMIT_BURST` | 15, 30 |
| `/home`, `/analytics` | `ANALYTICS_RATE_LIMIT_RPS`, `ANALYTICS_RATE_LIMIT_BURST` | 10, 20 |
| `/ai/*` | `AI_RATE_LIMIT_RPS`, `AI_RATE_LIMIT_BURST` | 3, 6 |
| `/physique-scans` | `PHYSIQUE_RATE_LIMIT_RPS`, `PHYSIQUE_RATE_LIMIT_BURST` | 2, 4 |

### Server environment (API process)

| Variable | Purpose |
|----------|---------|
| `DATABASE_URL` | Postgres DSN (**required**) |
| `JWT_SECRET` | HMAC secret, **≥32** characters (**required**) |
| `JWT_ACCESS_TTL` | Access token lifetime (default `15m`) |
| `JWT_REFRESH_TTL` | Refresh token lifetime (default `720h`) |
| `PORT` | Listen port (default `8080`) |
| `ENV` | e.g. `production` (affects Gin mode) |
| `OPENAI_API_KEY` | OpenAI API key for **`POST /ai/analyze-workout/*`** (if unset, that route returns **503**) |
| `OPENAI_MODEL` | Chat model (default **`gpt-4o-mini`**) |
| `PHYSIQUE_SCAN_MODEL` | Vision model for physique scans (default **`gpt-5.4-mini`**) |
| `PHYSIQUE_UPLOAD_DIR` | Local directory for stored scan images (default **`data/uploads/physique`**) |

---

## Health

### `GET /health`

**Auth:** none

**200:** `{ "status": "ok", "db": "up" }`

**503:** `{ "status": "unhealthy", "db": "down", "error": "..." }`

---

## Auth

All `/auth/*` routes use the **auth** rate limiter.

### `POST /auth/register`

**Auth:** none

**Body:**

```json
{
  "email": "user@example.com",
  "password": "min8chars"
}
```

**201:** `{ "user": { ... }, "tokens": { ... } }`

**400:** validation / weak password · **409:** email already registered · **500:** internal error

---

### `POST /auth/login`

**Auth:** none

**Body:**

```json
{
  "email": "user@example.com",
  "password": "..."
}
```

**200:** `{ "user": { ... }, "tokens": { ... } }`

**401:** invalid email or password · **500:** internal error

---

### `POST /auth/refresh`

**Auth:** none

**Body:**

```json
{
  "refresh_token": "<raw token from login/register; do not wrap in Postman {{ }} unless that variable exists>"
}
```

**200:** `{ "tokens": { ... } }` (same token pair shape as register/login, without `user`)

**401:** invalid / expired / revoked refresh token

---

### `GET /me`

**Auth:** required (no dedicated rate limit group beyond global middleware)

**200:** User object:

```json
{
  "id": "uuid",
  "email": "user@example.com",
  "auth_provider": "email",
  "created_at": "...",
  "updated_at": "..."
}
```

**401:** missing/invalid JWT · **404:** user not found · **500:** internal error

---

### Token pair (`tokens`)

```json
{
  "access_token": "...",
  "refresh_token": "...",
  "expires_in": 900,
  "token_type": "Bearer"
}
```

`expires_in` is seconds until access token expiry.

---

## Profile

**Auth:** required · **Rate limit:** profile group

### `GET /profile`

**200:** Profile (API-facing field names):

| Field | Notes |
|-------|--------|
| `user_id` | |
| `age`, `height_cm`, `weight_kg` | optional |
| `goal` | maps to DB `fitness_goal`: `muscle_gain`, `strength`, `fat_loss`, `general_fitness` |
| `experience` | maps to DB `training_experience`: `beginner`, `intermediate`, `advanced` |
| `preferred_split`, `injury_notes` | |
| `activity_level` | optional lifestyle activity outside the gym: `sedentary`, `light`, `moderate`, `active`, `very_active` (used for analytics calorie targets when set; unset defaults to `moderate` in scoring) |
| `strength_elo`, `strength_elo_rank`, `strength_elo_change_30d`, `last_strength_elo_update` | read-only in API (not written by `PUT`) |
| `updated_at` | present when a profile row exists |

---

### `PUT /profile`

Partial update: only JSON keys you send are merged.

**Body example:**

```json
{
  "age": 28,
  "height_cm": 178,
  "weight_kg": 82.5,
  "goal": "strength",
  "experience": "intermediate",
  "preferred_split": "Upper / Lower",
  "injury_notes": "...",
  "activity_level": "moderate"
}
```

Empty string (after trim) on string fields clears that field.

**Validation (400):**

- `age`: 10–120  
- `height_cm`: 50–300  
- `weight_kg`: 20–400  
- `goal` / `experience` / `activity_level`: allowed values only  
- `preferred_split`: ≤ 128 Unicode code points  
- `injury_notes`: ≤ 2000 Unicode code points  

**200:** same shape as `GET /profile`

---

## Exercises (catalog)

Catalog = system exercises (`is_custom = false`, `created_by` null).

**Auth:** required · **Rate limit:** exercise group

### `GET /exercises`

**Query:** `limit` (default **50**, max **100**), `offset` (default **0**, max **10000**)

**200:**

```json
{
  "exercises": [
    {
      "id": "uuid",
      "name": "Bench Press",
      "muscle_group": "chest",
      "equipment": "barbell",
      "is_custom": false,
      "created_by": null,
      "created_at": "..."
    }
  ]
}
```

---

### `GET /exercises/search`

**Query:** `q` **required** (trimmed, max **80** code points); optional `limit` (default/max **50**)

**200:** `{ "exercises": [...], "q": "bench" }`

**400:** missing `q` or `q` too long

Characters `%`, `_`, `\` in `q` are escaped for safe substring matching.

---

## Routines (user-owned)

**Auth:** required · **Rate limit:** routine group

Users only access routines where `user_id` matches the JWT subject.

### `POST /routines`

Create an empty user routine.

**Body:**

```json
{
  "name": "Push Day",
  "description": "optional"
}
```

If `name` is empty/whitespace after trim, server uses **`Untitled routine`**. Name/description length limits are enforced in the service layer.

**201:** Routine object with `exercises: []`

---

### `GET /routines`

**200:** `{ "routines": [ ... ] }` — each item includes `exercise_count`; not the full exercise list.

---

### `GET /routines/:id`

**200:** Full routine including `exercises` ordered by `position`. Each exercise row includes `exercise_name`.

**404:** not found or not owned by caller

---

### `PUT /routines/:id`

Update name and/or description. At least one of `name`, `description` must be present in the JSON.

**Body:**

```json
{
  "name": "Legs",
  "description": "optional"
}
```

**200:** Full routine (same as `GET /routines/:id`)

**400:** validation (e.g. empty name when `name` is sent) · **404:** not found

---

### `POST /routines/:id/exercises`

Add a line to the routine.

**Body:**

```json
{
  "exercise_id": "uuid",
  "target_sets": 3,
  "target_rep_min": 8,
  "target_rep_max": 12,
  "target_rpe": 8.5,
  "rest_seconds": 120,
  "notes": "optional",
  "position": 2
}
```

`exercise_id` is required. `position` is optional (append at end if omitted).

**201:** Routine exercise row (includes `exercise_name`)

**404:** routine not yours / unknown exercise · **400:** validation (rep range, notes length, etc.)

---

### `PUT /routines/:id/exercises/:routineExerciseId`

Partial update for one line. Path param: `routineExerciseId` = `routine_exercises.id`.

**Body (any subset):** `target_sets`, `target_rep_min`, `target_rep_max`, `target_rpe`, `rest_seconds`, `notes`, `position`

Empty `notes` (after trim) clears notes.

**200:** Updated routine exercise row

**404** / **400** (e.g. invalid `position`)

---

### `DELETE /routines/:id/exercises/:routineExerciseId`

**204:** No body. Remaining exercises renumbered.

**404:** not found / not yours

---

### Routine exercise JSON shape

Returned objects embed routine exercise fields plus `exercise_name`.

Fields include: `id`, `routine_id`, `exercise_id`, `position`, `target_sets`, `target_rep_min`, `target_rep_max`, `target_rpe`, `rest_seconds`, `notes`, `target_weight_kg` (column may exist from DB; add/update handlers do not set weight yet).

---

## Routine templates (global blueprints)

**Auth:** required · **Rate limit:** routine group

Templates are read-only. Users copy into their own `routines` / `routine_exercises`.

### `GET /routine-templates`

**200:** `{ "templates": [ { "id", "name", "description?", "created_at", "exercise_count" }, ... ] }`

---

### `GET /routine-templates/:id`

**200:** Template with `exercises` ordered by `position` (each line includes `exercise_name`).

**404:** unknown template

---

### `POST /routine-templates/:id/copy`

Creates a **new user routine** and copies all template exercises into `routine_exercises`.

**Body (optional):**

```json
{
  "name": "My Push Day (from template)"
}
```

If `name` is omitted or empty after trim, the new routine uses the template’s name.

**201:** New routine (response may omit populated exercises; use `GET /routines/:id` to load lines).

**404:** template not found

---

### Template exercise JSON shape

Same idea as routine exercises: template fields plus `exercise_name`. Uses `template_id` instead of `routine_id`.

---

## Workouts (logging + Strength Elo)

**Auth:** required · **Rate limit:** `WORKOUT_RATE_LIMIT_*` (defaults 25 RPS / 50 burst)

### `POST /workouts`

Start an in-progress session (`completed_at` null until finish).

**Body:**

```json
{
  "routine_id": "optional-uuid",
  "name": "Optional session name"
}
```

If `routine_id` is set, it must belong to the current user. Empty string is treated as omitted.

**201:** Workout with `sets: []`

---

### `GET /workouts`

**200:** `{ "workouts": [ ... ] }` — recent sessions (default last **30**), newest first. Rows include `total_volume_kg`, `duration_seconds`, `stats` when present (after finish).

---

### `GET /workouts/:id`

**200:** Workout plus `sets` (each set includes `exercise_name`).

**404:** not found / not yours

---

### `POST /workouts/:id/sets`

**Body:**

```json
{
  "exercise_id": "uuid",
  "set_number": null,
  "reps": 5,
  "weight_kg": 100,
  "rpe": 8.5,
  "is_failure": false,
  "notes": null
}
```

`reps` and `weight_kg` are required and must be **> 0**. `set_number` optional (auto: next number for that exercise in this workout).

**201:** Set row with `exercise_name`

**404:** workout / exercise · **409:** workout already finished · **400:** invalid payload

---

### `PUT /workouts/:id/sets/:setId`

Partial update. Resulting `reps` and `weight_kg` must remain **> 0**.

**400 / 404 / 409** as above.

---

### `DELETE /workouts/:id/sets/:setId`

**204:** no body

---

### `POST /workouts/:id/finish`

Completes the workout, persists **volume**, **duration**, **stats** JSON, computes **e1RM** (Brzycki) per exercise, **PRs** vs prior completed sessions, and updates **Strength Elo** when possible.

**Body (optional):** `{ "notes": "..." }` (merged into workout `notes` if provided)

**200:** `FinishStats`:
`
- `total_volume_kg`, `duration_seconds`, `set_count`, `exercise_count`
- `e1rm_by_exercise`: `{ exercise_id, exercise_name, best_e1rm_kg }[]`
- `prs`: `{ exercise_id, exercise_name, previous_best_e1rm_kg, new_best_e1rm_kg }[]` (only lifts that beat historical e1RM)
- `strength_elo`: updated when **profile `weight_kg` > 0** and the finished session includes **≥ 2 benchmark lifts** with a countable e1RM.
  - Benchmarks (by exercise name): `Bench Press`, `Squat`, `Deadlift`, `OHP` / `Overhead Press`, `Barbell Row` / `Pendlay Row`
  - `before`, `after`, `delta`, `change_30d` (sum of Elo deltas from `strength_elo_history` in the last 30 days), `bodyweight_kg`, `session_score_bw` (average of per-benchmark normalized strength: `(e1RM / bodyweight) / refLift`, each term capped, then averaged; `refLift` is a fixed reference ratio per benchmark so typical deadlift kg/BW does not automatically outweigh bench)
- If bodyweight is missing, there are no valid weighted sets for e1RM, **or fewer than 2 benchmark lifts are present**: `strength_elo.skipped: true`, Elo unchanged, no new `strength_elo_history` row.

Also writes `workouts.stats` JSON and, when Elo runs, appends **`strength_elo_history`** and upserts **`profiles`** strength Elo fields.

**409:** already finished

---

## Recovery check-ins

**Auth:** required · **Rate limit:** `RECOVERY_RATE_LIMIT_*` (defaults 15 RPS / 30 burst)

Daily (per calendar date, **UTC**) log: **sleep hours**, **energy / readiness** (1–5), **calories**, **protein (g)**, optional **notes**. Same-day `POST` **upserts** that row.

### `POST /recovery-checkins`

**Body:**

```json
{
  "checkin_date": "2026-05-12",
  "sleep_hours": 7.5,
  "energy_readiness": 4,
  "calories_kcal": 2400,
  "protein_g": 160,
  "notes": "felt ok"
}
```

- `checkin_date`: optional `YYYY-MM-DD`; default **today UTC**
- `sleep_hours`: **required**, **0–24**
- `energy_readiness`: **required**, integer **1–5** (how ready / energetic you feel)
- `calories_kcal`: **required**, **0–20000**
- `protein_g`: **required**, **0–800** (grams)
- `notes`: optional, ≤ **2000** chars

**201:** saved check-in (same shape as list items).

### `GET /recovery-checkins/latest`

**200:** `{ "checkin": { ... } }` — most recent row by `checkin_date` (then `updated_at`).

**404:** `{ "error": "no check-ins yet" }`

### `GET /recovery-checkins?from=&to=`

Query params (each optional `YYYY-MM-DD`):

- `from` — default **29 days before** `to` (inclusive 30-day window with `to`)
- `to` — default **today UTC**

**400:** invalid dates or `from` after `to`

**200:** `{ "checkins": [ { "id", "checkin_date", "sleep_hours", "energy_readiness", "calories_kcal", "protein_g", "notes?", "created_at", "updated_at" } ] }` ordered by `checkin_date` ascending.

---

## Home & analytics

**Auth:** required · **Rate limit:** `ANALYTICS_RATE_LIMIT_*` (defaults 10 RPS / 20 burst) on **`/home`** and **`/analytics/*`**.

### `GET /home`

Lightweight **home tab** summary (UTC windows where applicable).

**200:** `strength_elo`, `strength_elo_rank`, `elo_change_30d` (from profile), **`sharpness`** (always present: full **`SharpnessOverview`** from recovery check-ins in the last **7** UTC days when any exist; if none, **`score`** and the 0–1 components are **0** but **`target_calories_kcal`**, **`target_protein_g`**, **`activity_level_resolved`**, and **`calorie_activity_multiplier`** still reflect profile goal/weight/activity), **`latest_workout`** (most recent completed session snapshot: `workout_id`, `completed_at`, `total_volume_kg`, `duration_seconds`, `set_count`), **`weekly_volume_kg`** / **`weekly_volume_window_days`** (**7**), **`workout_consistency`** (`completed_last_28_days`, `avg_per_week`), **`streak_days`** (consecutive UTC calendar days with ≥1 completed workout, counting backward from the most recent workout day).

### `GET /analytics/exercises`

**Progress tab** — list of exercises the user has trained (recent **36** completed workouts with **`workout_sets`**; **Brzycki** e1RM per session). Includes exercises with **≥1** session in that window (first workout still lists lifts).

**200:** `{ "exercises": [ ... ] }` — sorted by largest absolute `e1rm_change_kg` (ties by higher `latest_e1rm_kg`). With only one session in the window, **`e1rm_change_kg`** is **0**, **`e1rm_change_pct`** is **0** when a baseline e1RM exists, and **`trend`** is **`flat`**. **`latest_*`**, **`e1rm_change_*`**, **`data_points`**, and **`trend`** use the recent **36** completed workouts with logged sets. **`absolute_best_*`** is the user’s **lifetime** best Brzycki e1RM (and the `workout_sets` row that produced it) across **all** completed workouts, not capped to that window.

### `GET /analytics/exercises/:exerciseId`

**Exercise detail** — per-workout history for one exercise (up to **60** recent completed workouts).

**200:** `exercise_id`, `exercise_name`, **`absolute_best_e1rm_kg`** / **`absolute_best_set`** / **`absolute_best_workout_id`** / **`absolute_best_completed_at`** — **lifetime** best Brzycki e1RM and the `workout_sets` row that produced it (all completed workouts). **`history`** is still limited to up to **60** recent completed workouts: `[ { "workout_id", "completed_at", "best_set", "best_e1rm_kg", "volume_kg", "prs"?: [...] } ]` (oldest → newest). **`latest_comparison`** (omitted unless **`history`** has **≥2** entries): compares the **last** history entry (newest session) vs the **second-to-last** — `previous_completed_at` (that older session’s `completed_at`), `e1rm_change_kg`, `e1rm_change_pct` (vs previous best e1RM; omitted if previous e1RM is 0), `volume_change_kg`, `volume_change_pct` (vs previous volume; omitted if previous volume is 0), `best_set_previous`, `best_set_current` (`reps` / `weight_kg`). **`trend_summary`**: `up` / `flat` / `down` / `single_session` / `no_data` (unchanged: from the same last two **`history`** entries when ≥2).

### `GET /analytics/workouts/:workoutId/context`

Structured payload for **analyze workout** / AI (workout must belong to the user).

**200:** `workout` (full workout row + **`sets`** with exercise names), **`profile_basics`** (`goal`, `experience`, `injury_notes`, `strength_elo`, `weight_kg` from profile — always present), **`previous_same_routine`**: when **`first_session`**: `true`, only **`first_session`** is set (no **`latest`** mirror of the current workout); when a prior same-routine session exists: **`latest`** (current), **`previous`**, volume/duration/set deltas. Same match rules: **`routine_id`**, else **`name`** when `routine_id` null. **`exercise_comparisons`** when a previous session exists. **`prs`**, **`strength_elo_delta`**, **`recent_recovery_checkins`** (last **7d**), **`sharpness`**, **`relevant_recent_workouts`**: up to **8** other completed workouts (**excludes** the workout in the URL by id, not only “skip index 0”), each with `workout_id`, `completed_at`, `total_volume_kg`, `duration_seconds`, `set_count`, and **`exercises`**: `[ { "exercise_id"?, "exercise_name", "best_set"?, "best_e1rm_kg" } ]` (Brzycki best set per lift on that session).

**404:** workout not found / not yours.

### `GET /analytics/coach-context`

Structured bundle for **coach / AI** (not a minimal UI tab). **Auth** + analytics rate limit.

**Limits:** last **5** completed workouts (rich shape); up to **5** user routines (**`updated_at`** desc) each with **`exercises`**; top **8** exercise progression rows (same logic as **`GET /analytics/exercises`**, Brzycki + lifetime PRs); up to **15** recent AI insights; up to **25** pending AI actions.

**200:** JSON object:

- **`profile`** — `CoachProfileView` (same field names as **`GET /profile`** for goals, experience, body metrics, embedded Strength Elo fields, etc.).
- **`strength_elo_summary`** — `current_elo`, `rank`, `change_30d`, `last_updated` (compact block from profile; omitted if no profile).
- **`sharpness`** — same **`SharpnessOverview`** as **`GET /home`** when there is at least one recovery check-in in the last **7** UTC days; otherwise omitted.
- **`recovery`** — **`latest`**: most recent check-in in that **7d** window (`checkin_date`, sleep, energy, calories, protein, optional `notes`). **`averages_7d`**: `days_with_data`, mean `sleep_hours`, mean `energy_readiness`, mean `calories_kcal`, mean `protein_g` over those check-ins.
- **`recent_workouts`** — array of **5** objects, newest first: `workout_id`, `name`, `routine_id`, `completed_at`, `total_volume_kg`, `duration_seconds`, `strength_elo_delta` (from finish **`stats`** when present), **`exercises`**: ordered as logged, each `{ exercise_id, exercise_name, sets: [{ set_number, reps?, weight_kg?, rpe?, is_failure }], best_set?, best_e1rm_kg, volume_kg }`.
- **`active_routines`** — up to **5** **`routine.Routine`** rows with **`exercises`** filled (`RoutineExerciseOut`: targets, rest, notes, `exercise_name`, etc.).
- **`exercise_progression`** — up to **8** objects with the same shape as **`GET /analytics/exercises`** rows (`latest_*`, **`absolute_best_*`** lifetime, `e1rm_change_*`, `data_points`, `trend`).
- **`recent_ai_insights`**, **`pending_ai_actions`** — pending structured actions awaiting user accept/reject.
- **`active_routines`** — `{ routine_id, routine_name, exercises: [{ routine_exercise_id, exercise_id, exercise_name, target_sets, target_rep_min, target_rep_max, rest_seconds, position }] }`.

---

## AI (post-workout analysis)

**Auth:** required · **Rate limit:** `AI_RATE_LIMIT_*` (defaults **3** RPS / **6** burst) on **`/ai/*`**.

**Database:** Run migration **`000012_ai_insights_title_unique`** so `ai_insights` has **`title`** and **`UNIQUE(workout_id)`** (one saved analysis per workout).

### `POST /ai/analyze-workout/:workoutId`

Generate **or** return the saved coaching analysis for a **completed** workout owned by the user.

**Flow:** Ensures workout exists and **`completed_at`** is set → if a row already exists for this **`workout_id`** (and user), returns it **without** calling OpenAI → otherwise loads context via **`analytics.Service.WorkoutContextJSON`** (same data as **`GET /analytics/workouts/:workoutId/context`**, implemented as **`WorkoutContext`** + pretty JSON in one place—no separate copy in **`main`**) → calls OpenAI → saves **`insight_type`**: `workout_analysis` into **`ai_insights`**. Concurrent duplicate inserts are handled (unique constraint).

**200:** `{ "id", "workout_id", "insight_type", "title", "message", "structured_json"?, "created_at" }` — **`message`** is the main coaching text; **`structured_json`** may hold small metadata (not the full LLM context).

**400:** workout not completed.

**404:** workout not found / not yours.

**503:** `OPENAI_API_KEY` not configured.

### `GET /ai/insights`

List saved insights for the user (**never** calls OpenAI). Optional query **`limit`** (default **50**, max **100**).

**200:** `{ "insights": [ { "id", "workout_id"?, "insight_type", "title", "summary", "created_at" } ] }` — **`summary`** is the stored message body (`generated_text`).

### `POST /ai/chat`

Multi-turn **coach chat**. On a **new** conversation (omit **`conversation_id`**), the server loads **`analytics.Service.CoachContextJSON`** — the same payload as **`GET /analytics/coach-context`** — and stores it once as a hidden **system** message. Follow-up messages in that thread use stored history (context is not re-fetched every turn).

**Body:** `{ "message": "...", "conversation_id"?: "uuid" }`

Coach context includes **`active_routines`** with **`routine_exercise_id`** per line (for safe edits). The model returns JSON with a user-visible **`message`** and optional **`proposed_actions`**. Valid actions are stored in **`ai_actions`** as **`pending`** (never auto-applied). Invalid or ambiguous exercise names are dropped; **`clarification`** may be returned when the catalog match is unclear.

**200:** `{ "conversation_id", "assistant": { ... }, "proposed_actions"?: [ ... ], "clarification"?: { "clarification_required", "message", "possible_matches" } }`

**400:** empty message · **404:** unknown **`conversation_id`** · **503:** no **`OPENAI_API_KEY`**

### `GET /ai/actions/pending`

List **`pending`** coach actions for the user (optional **`limit`**, default **50**).

**200:** `{ "actions": [ { "id", "action_type", "target_type", "target_id", "payload", "reason", "status", "created_at", ... } ] }`

### `POST /ai/actions/:id/accept`

Re-validate ownership and payload, apply the change deterministically, set status **`applied`**.

**200:** updated action row · **404** / **409** if missing or not pending · **400** if target gone or validation fails

### `POST /ai/actions/:id/reject`

Mark **`rejected`**; no data mutation.

**200:** updated action row

**Database:** migration **`000015_ai_actions_coach`** extends **`ai_actions`** (`source_type`, `source_id`, `target_type`, `target_id`, `reason`, `applied_at`).

### `GET /ai/chat/conversations`

List coach threads for the user (**no** OpenAI). Query **`limit`** (default **30**, max **100**).

**200:** `{ "conversations": [ { "id", "title", "created_at", "updated_at" } ] }`

### `GET /ai/chat/conversations/:conversationId/messages`

User/assistant messages only (**no** OpenAI, system context omitted). **404** if not yours.

**200:** `{ "conversation_id", "messages": [ ... ] }`

**Database:** migration **`000013_coach_chat`** — tables **`coach_conversations`**, **`coach_messages`**.

---

## Physique scans (body fat estimate)

**Auth:** required · **Rate limit:** `PHYSIQUE_RATE_LIMIT_*` (defaults **2** RPS / **4** burst).

Lightweight vision estimate from physique photos. **Not medical advice** — integer body fat % only, with **`low` | `medium` | `high`** confidence.

**Database:** migration **`000014_physique_scans`** — table **`physique_scans`** (`id`, `user_id`, `image_url`, `estimated_body_fat_pct`, `confidence`, `created_at`).

Stored images are served at **`GET /uploads/physique/{user_id}/{scan_id}/{index}.jpg`** (or `.png` / `.webp`).

### `POST /physique-scans`

**Content-Type:** `multipart/form-data`

**Fields:** one or more files — **`images`** (preferred) or **`image`**. Up to **3** files, **8MB** each. Types: **jpeg**, **png**, **webp**.

**Flow:** save image(s) → OpenAI vision (`PHYSIQUE_SCAN_MODEL`, requires **`OPENAI_API_KEY`**) → persist scan → return estimate.

**201:**

```json
{
  "id": "uuid",
  "estimated_body_fat_pct": 16,
  "confidence": "medium",
  "image_url": "/uploads/physique/{user_id}/{scan_id}/0.jpg"
}
```

**400:** no images / too many / too large / unsupported type · **503:** no **`OPENAI_API_KEY`**

### `GET /physique-scans`

List scans for the user, newest first. Query **`limit`** (default **50**, max **100**).

**200:** `{ "scans": [ { "id", "user_id", "image_url", "estimated_body_fat_pct", "confidence", "created_at" } ] }`

### `GET /physique-scans/:id`

**200:** single scan object (same fields as list items).

**404:** not found / not yours.

---

## Current scope

Implemented in this repository:

- Health, auth (`/auth/*`, `/me`), profile, exercise catalog, user routines, routine templates, **workouts (start / sets / finish + BW-relative Strength Elo + history)**, **recovery check-ins**, **home + analytics** (`/home`, `/analytics/exercises`, `/analytics/exercises/:id`, `/analytics/workouts/:id/context`, `/analytics/coach-context`), **AI** (`POST /ai/analyze-workout/:workoutId`, `GET /ai/insights`, **`POST /ai/chat`**, **`GET /ai/chat/conversations`**, **`GET /ai/chat/conversations/:id/messages`**), **physique scans** (`POST /physique-scans`, `GET /physique-scans`, `GET /physique-scans/:id`).

Not implemented as HTTP API here yet: OAuth (Google/Apple), etc.

---

## Postman / clients

- Use **`Authorization: Bearer <access_token>`** on protected routes.  
- Do **not** paste the raw refresh token inside `{{ ... }}` unless that is a real Postman variable name; otherwise Postman sends the wrong value and refresh returns **401**.
