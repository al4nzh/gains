# Gains — Mobile App Product Spec (for frontend)

Use this with **`docs/API.md`** (all HTTP details). This doc is the **product map**: screens, flows, and MVP scope.

---

## What Gains is

A **strength-training app** for logging workouts, tracking progression and recovery, managing routines, and getting **AI coaching** (chat + post-workout analysis). Optional **physique scan** estimates body fat from photos (not medical advice).

**Backend:** REST API at `http://localhost:8080` (dev).  
**Auth:** JWT access token + refresh token. Header: `Authorization: Bearer <access_token>`.

**Android emulator → API on PC:** `http://10.0.2.2:8080`  
**Physical device on same Wi‑Fi:** `http://<your-pc-lan-ip>:8080`

---

## Tech assumptions (suggested)

- **Flutter** or **React Native**, Android first (Windows dev OK).
- Package name: pick once, e.g. `com.alanz.gains` (needed later for Google OAuth).
- Secure storage for `access_token` + `refresh_token`.
- Auto-refresh on **401** using `POST /auth/refresh`.
- API contract: **`docs/API.md`** only — do not guess endpoints.

---

## MVP build order

1. Auth (email) + token storage + `/me`
2. Profile GET/PUT (onboarding)
3. **Home** tab (`GET /home`)
4. **Workouts** (start → log sets → finish)
5. **Routines** (list, detail, templates copy)
6. **Recovery** check-in
7. **Progress** (exercise analytics list + detail)
8. **AI coach** chat + action review cards
9. Post-workout AI analysis (optional button after finish)
10. Physique scan (camera upload)
11. Google Sign-In (when Android OAuth client exists)

---

## Navigation (recommended)

Bottom tabs:

| Tab | Purpose |
|-----|---------|
| **Home** | Dashboard: Elo, sharpness, latest workout, targets |
| **Train** | Active workout + history + start workout |
| **Routines** | My routines + browse templates |
| **Progress** | Exercise analytics |
| **Coach** | AI chat + pending actions |

**Profile / Settings** — stack from avatar: profile, recovery log, physique scans, logout.

---

## 1. Auth & onboarding

### Screens

- **Welcome** — Email register / login; later: Continue with Google (Android).
- **Register** — email, password (min 8).
- **Login** — email, password.

### API

- `POST /auth/register` → save `tokens`, go onboarding or home.
- `POST /auth/login` → save `tokens`.
- `POST /auth/refresh` — on access token expiry.
- `GET /me` — validate session on app start.
- Later: `POST /auth/google` with `id_token`.

### Onboarding (first launch after register)

- `GET /profile` → if empty, show **Profile setup**:
  - goal (`muscle_gain`, `strength`, `fat_loss`, `general_fitness`)
  - experience, height, weight, injury notes, activity level
- `PUT /profile`

---

## 2. Home tab

### Screen: Home

**API:** `GET /home`

**Show (when present):**

- Strength Elo + rank + 30d change
- **Sharpness** score (recovery/nutrition/training signal)
- Latest completed workout snapshot
- Daily targets (calories, protein from profile logic)
- Quick actions: **Start workout**, **Check-in**, **Open coach**

---

## 3. Train tab (workouts)

### Screen: Workout history

**API:** `GET /workouts` — list completed/in-progress.

### Screen: Start workout

- Optional: pick **routine** (`GET /routines`) or custom name.
- **API:** `POST /workouts` — `{ "routine_id?", "name?" }`. Only **one** active workout at a time; **409** includes `active_workout_id` if user already has a session in progress.
- **Discard:** `DELETE /workouts/:id` while in progress (clears session without finish stats).

### Screen: Active workout (live logging)

- List exercises / sets for this workout.
- Add set: pick exercise from catalog (`GET /exercises/search?q=`).
- **API:** `POST /workouts/:id/sets` — reps, weight_kg, rpe, is_failure.
- Edit/delete set: `PUT` / `DELETE .../sets/:setId`.

### Screen: Finish workout

- **API:** `POST /workouts/:id/finish`
- Show summary: volume, duration, Elo delta, PRs, e1rm highlights from `stats`.
- CTA: **Analyze with AI** → `POST /ai/analyze-workout/:workoutId` (show insight or cached).

---

## 4. Routines tab

### Screen: My routines

**API:** `GET /routines` — cards with `exercise_count`.

### Screen: Routine detail

**API:** `GET /routines/:id` — ordered exercises with targets (sets, rep min/max, rest).

- Edit name/description: `PUT /routines/:id`
- Delete routine: `DELETE /routines/:id`
- Add exercise: search catalog → `POST /routines/:id/exercises`
- Edit line: `PUT /routines/:id/exercises/:routineExerciseId`
- Remove line: `DELETE ...`

### Screen: Template library

**API:** `GET /routine-templates` → detail `GET /routine-templates/:id`

- **Use template** → `POST /routine-templates/:id/copy` → open new routine.

### Screen: Generate with AI (onboarding or Routines tab)

1. User enters request (e.g. “4-day upper/lower, shoulder-friendly”).
2. **API:** `POST /ai/generate-routines` `{ "message": "..." }`.
3. If **`clarification`** → show matches, let user rephrase and retry.
4. Preview **`title`** + **`routines`** (names, exercises, sets/reps/rest) — **not saved yet**.
5. **Confirm** → `POST /ai/generated-routines/:draftId/confirm`.
6. Navigate to **My Routines** with created plans.

Requires profile filled (goal, experience, etc.) for best results.

### Start workout from routine

`POST /workouts` with `routine_id` — user still logs sets manually (targets are hints only, not pre-filled by API today).

---

## 5. Recovery (Daily Readiness)

**Meaning:** last night's sleep, today's energy, yesterday's nutrition.

### Daily Readiness card (Home)

**Prompt logic (frontend only):**

- Show card when **local time ≥ 5:00 AM** and **no check-in for today's local date**
- Card is dismissible / skippable (persist dismiss in local storage)
- Do **not** use rolling 24h windows

**API:** `GET /recovery-checkins/status?checkin_date=YYYY-MM-DD` — pass **local today**; use `has_checkin_today` + local 5 AM rule for UI. `should_prompt` is a hint (`!has_checkin_today`); full gating stays on the client.

### Screen: Daily check-in

**API:** `POST /recovery-checkins`

- `checkin_date` — **local** `YYYY-MM-DD` (required from app for correct day boundary)
- `sleep_hours`, `energy_readiness` (1–5), `calories_kcal`, `protein_g`, `notes`
- Same-day POST **upserts** (one row per date)

### Screen: Latest / history

- `GET /recovery-checkins/latest`
- `GET /recovery-checkins?from=&to=` — pass **local** date bounds for charts

---

## 6. Progress tab

### Screen: Exercises list

**API:** `GET /analytics/exercises` — progression rows (latest e1rm, trend, lifetime best).

### Screen: Exercise detail

**API:** `GET /analytics/exercises/:exerciseId` — history, trend summary, `latest_comparison`.

---

## 7. Coach tab (AI)

### Screen: Coach chat

- New thread: `POST /ai/chat` with `{ "message" }` only.
- Continue: same with `"conversation_id"`.
- List threads: `GET /ai/chat/conversations`
- History: `GET /ai/chat/conversations/:id/messages`
- Delete thread: `DELETE /ai/chat/conversations/:id`

**Response may include:**

- `assistant.content` — show as chat bubble.
- `proposed_actions[]` — **review cards** under the message (do not auto-apply).
- `clarification` — show “pick exercise” UI if `possible_matches` present.

### Screen: Pending actions (or inline cards)

**API:**

- `GET /ai/actions/pending`
- **Accept** → `POST /ai/actions/:id/accept` (applies routine/profile change).
- **Reject** → `POST /ai/actions/:id/reject`

**Action types (coach can propose):** update goal, injury notes, bodyweight, height; add/remove/replace routine exercise; update sets/reps/rest; rename routine. User must confirm every change.

### Screen: Insights list (optional)

**API:** `GET /ai/insights` — past workout analyses.

---

## 8. Physique scan (optional feature)

### Screen: New scan

- Camera / gallery → multipart `POST /physique-scans` field `images`.
- Show result: `estimated_body_fat_pct` (integer), `confidence` (`low`|`medium`|`high`).

### Screen: Scan history

- `GET /physique-scans`, detail `GET /physique-scans/:id`
- Image URL: `{baseUrl}{image_url}` e.g. `/uploads/physique/...`

---

## 9. Profile & settings

**API:** `GET /profile`, `PUT /profile`

Fields: age, height_cm, weight_kg, goal, experience, preferred_split, injury_notes, activity_level, strength_elo (read-only from server).

Logout: clear tokens locally (no revoke endpoint required for MVP).

---

## UX rules

- Show API errors as human text (`error` field).
- **429** → “Slow down, try again.”
- **503** on AI routes → “Coach unavailable” (no API key on server).
- Never claim AI already changed data until user **Accepts** an action.
- Physique / coach: no medical claims; body fat is an estimate only.
- Loading states on AI calls (can take 30–90s).

---

## Data to persist locally

| Key | Use |
|-----|-----|
| `access_token` | API calls |
| `refresh_token` | Refresh flow |
| `user_id` | Optional cache from `/me` |

---

## Out of scope for MVP UI (backend may exist)

- OAuth Apple until iOS/Mac ready (endpoint exists).
- Editing workout after finish.
- Social / friends / leaderboards.
- Payments / subscriptions.

---

## Cursor prompt starter

Copy into a new `mobile/` chat:

```
Build a Flutter app in mobile/ for Gains per docs/FRONTEND_APP.md and docs/API.md.

Phase 1: email auth, secure token storage, refresh on 401, profile onboarding, home tab (GET /home).
Use base URL from env. Android emulator uses http://10.0.2.2:8080.
Material 3, dark gym aesthetic, bottom navigation as in FRONTEND_APP.md.
```

---

## Reference

- **HTTP details:** `docs/API.md`
- **This file:** product + screens only
