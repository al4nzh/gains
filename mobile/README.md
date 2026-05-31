# Gains Mobile (Flutter)

Flutter app for **iOS + Android**. Lives in the **gainsai monorepo** — app code only here; API and product specs live one level up.

## Docs (do not duplicate)

| Doc | Path | Use for |
|-----|------|---------|
| **HTTP contract** | [`../docs/API.md`](../docs/API.md) | Every endpoint, body, error, rate limit |
| **Product / screens** | [`../docs/FRONTEND_APP.md`](../docs/FRONTEND_APP.md) | Tabs, flows, MVP order, UX rules |

**Cursor:** open the **`gainsai/`** repo root (not only `mobile/`), then `@docs/API.md` and `@docs/FRONTEND_APP.md` work from any chat.

**Rule:** implement against `docs/API.md` only — do not guess URLs or fields.

**Bundle ID:** `com.alanz.gains`

## Monorepo layout

```
gainsai/
  docs/API.md
  docs/FRONTEND_APP.md
  mobile/          ← you are here (lib/, android/, ios/)
  cmd/ …         ← Go API
```

## Prerequisites

| Platform | On Windows | Notes |
|----------|------------|--------|
| **Android** | Android Studio + SDK + emulator | `flutter doctor` → Android toolchain ✓ |
| **iOS** | Mac + Xcode | `ios/` is in repo; build/run on Mac |
| **API** | Backend on port **8080** | From repo root when testing auth/home |

## API base URL

```bash
flutter run --dart-define=API_BASE_URL=<url>
```

| Target | URL |
|--------|-----|
| Android emulator | `http://10.0.2.2:8080` (default in `lib/core/config/api_config.dart`) |
| iOS Simulator | `http://127.0.0.1:8080` |
| Physical device (same Wi‑Fi) | `http://<your-pc-lan-ip>:8080` |

Debug builds allow cleartext HTTP (Android debug manifest, iOS `NSAllowsLocalNetworking`).

## Google + Apple Sign-In

Backend routes: `POST /auth/google`, `POST /auth/apple` (see `docs/API.md`). Mobile sends provider `id_token`; server returns the same `user` + `tokens` as email login.

### 1. API `.env`

```env
GOOGLE_OAUTH_CLIENT_IDS=<your-web-client-id>.apps.googleusercontent.com
APPLE_OAUTH_CLIENT_ID=com.alanz.gains
```

`GOOGLE_OAUTH_CLIENT_IDS` must include the **Web application** client ID (the one you pass to the app as `GOOGLE_SERVER_CLIENT_ID`).

### 2. Google Cloud Console

1. Create a project → **APIs & Services → Credentials**
2. **OAuth client → Web application** → copy client ID → `.env` + mobile `GOOGLE_SERVER_CLIENT_ID`
3. **OAuth client → Android** → package `com.alanz.gains` + SHA-1 of your keystore  
   Debug SHA-1: `cd mobile/android && ./gradlew signingReport` (or Android Studio → Gradle → signingReport)
4. **OAuth client → iOS** → bundle `com.alanz.gains` → mobile `GOOGLE_IOS_CLIENT_ID`

### 3. Apple Developer (iOS)

1. App ID `com.alanz.gains` → enable **Sign in with Apple**
2. `APPLE_OAUTH_CLIENT_ID=com.alanz.gains` on the API
3. Open `mobile/ios/Runner.xcworkspace` in Xcode once — confirm **Sign in with Apple** capability (entitlements file is in repo)

### 4. Run with dart-define

**Android emulator:**

```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
```

**iOS Simulator:**

```bash
flutter run \
  --dart-define=API_BASE_URL=http://127.0.0.1:8080 \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=<ios-client-id>.apps.googleusercontent.com
```

Welcome screen → **Continue with Google** (Android + iOS). **Continue with Apple** (iOS only). Email signup on both.

## Run

```bash
cd mobile
flutter pub get
flutter run
```

Launch configs: `.vscode/launch.json`.

## MVP build order (from FRONTEND_APP.md)

1. Auth (email) + secure tokens + refresh on 401 + `GET /me`
2. Profile onboarding (`GET` / `PUT /profile`)
3. Home tab (`GET /home`)
4. Workouts → Routines → Recovery → Progress → Coach → physique → Google Sign-In

**Also in spec (post–Phase 1):** AI routine generation (`POST /ai/generate-routines`, confirm draft) — see Routines section in FRONTEND_APP.md.

**UI note:** recovery `energy_readiness` is **1–5** per API.md (FRONTEND_APP.md still says 1–10 in one place — follow API).

## Project layout

```
lib/
  main.dart
  app.dart
  core/
    config/api_config.dart
    theme/app_theme.dart
```

## Dependencies

- `dio` — HTTP
- `flutter_secure_storage` — tokens
- `go_router` — navigation (Phase 1+)
