# Deploying Gains to production

Beta → public release checklist for the **Go API** + **Flutter app**.

---

## 1. Email (required for email signup)

Email verification and forgot-password **require** a real mail provider in prod (`ENV=production`).

### Option A — Resend (recommended)

1. Sign up at [resend.com](https://resend.com)
2. **Domains** → add your domain (e.g. `yourdomain.com`)
3. Add the DNS records Resend gives you (SPF, DKIM) — wait until verified
4. **API Keys** → create key → copy `re_...`
5. Set on your server:

```env
ENV=production
RESEND_API_KEY=re_xxxxxxxx
EMAIL_FROM=Gains <noreply@yourdomain.com>
```

Until your domain is verified, Resend lets you send **only to your own signup email** for testing.

### Option B — SendGrid (SMTP)

1. SendGrid → Settings → API Keys → create with Mail Send
2. Authenticate your domain (same DNS idea as Resend)
3. Set:

```env
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER=apikey
SMTP_PASS=SG.xxxx
EMAIL_FROM=Gains <noreply@yourdomain.com>
```

### Local dev (no provider)

Leave `RESEND_API_KEY` and `SMTP_HOST` empty — emails print in the API console. `ENV` must **not** be `production`.

---

## 2. Database

Use managed Postgres (Neon, Supabase, Railway, RDS, etc.).

```env
DATABASE_URL=postgres://user:pass@host:5432/gains?sslmode=require
```

Run migrations **before** first traffic:

```bash
go run ./cmd/migrate up
# or in Docker:
docker run --rm --env-file .env your-image /app/migrate up
```

---

## 3. API secrets

```env
ENV=production
JWT_SECRET=<openssl rand -hex 32>
GOOGLE_OAUTH_CLIENT_IDS=<web-client-id>.apps.googleusercontent.com
APPLE_OAUTH_CLIENT_ID=com.alanz.gains
OPENAI_API_KEY=sk-...
APP_DEEP_LINK_BASE=gains://auth
```

Copy template: `.env.production.example`

---

## 4. Deploy the API

### Docker (any VPS / Railway / Fly / Render)

```bash
docker build -t gains-api .
docker run -d --name gains-api -p 8080:8080 --env-file .env \
  -v gains-uploads:/app/data/uploads/physique gains-api
```

Put **HTTPS** in front (Caddy, nginx, Cloudflare, or platform TLS) → e.g. `https://api.yourdomain.com`

### Health check

`GET /health` → `200 {"status":"ok","db":"up"}`

---

## 5. Mobile app (beta build)

Production API URL:

```bash
cd mobile
flutter build appbundle \
  --dart-define=API_BASE_URL=https://api.yourdomain.com \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
```

| Platform | Store | OAuth |
|----------|-------|-------|
| Android | Play Console internal testing | Android OAuth client + **release** SHA-1 |
| iOS | TestFlight (Mac + Apple Dev) | Sign in with Apple + iOS Google client |

---

## 6. Pre-beta checklist

- [ ] `ENV=production` + `RESEND_API_KEY` + verified domain + `EMAIL_FROM`
- [ ] `DATABASE_URL` with `sslmode=require`
- [ ] Migrations applied
- [ ] HTTPS on API
- [ ] Strong `JWT_SECRET` (32+ bytes)
- [ ] Google OAuth Web + Android (+ iOS) clients
- [ ] Test: register → email arrives → verify → login → forgot password
- [ ] Privacy policy URL live at `https://gainsai.net/privacy` (source: `docs/legal/`, see `docs/legal/README.md`)
- [ ] Terms URL live at `https://gainsai.net/terms` (app links via `TERMS_URL`)
- [ ] Release signing (Android keystore, iOS certs)

---

## 7. After beta (public store)

- [ ] Apple Sign-In on iOS (required if Google/email social login)
- [x] Account deletion flow (`DELETE /me`, Profile → Delete account)
- [ ] Fix physique photo public URL issue before enabling scans widely
- [ ] Monitoring / backups on Postgres

---

## Quick Resend test (production server)

1. Deploy with `RESEND_API_KEY` + `EMAIL_FROM`
2. Register a **new** email account in the app
3. Inbox should get “Verify your Gains email” within seconds
4. Tap link or paste code in app

If emails fail, check API logs for `resend:` errors (usually unverified domain or wrong `EMAIL_FROM`).
