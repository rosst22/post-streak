# Post Streak

Post Streak is an iOS app for maintaining a consistent publishing habit across
Instagram, TikTok, YouTube, and other platforms. It tracks only posts and cadence—
never views, followers, likes, or engagement.

The home screen shows a weekly streak, target progress, and a 365-day heatmap.
Logging from the app takes two taps: **Log a post → platform**. A Share Extension
accepts links from another app, detects the platform from the URL, and logs without
opening Post Streak. The second tab shows accepted friends' newest posts.

> Status: the backend is live on Render, the production Supabase schema is installed
> with RLS and direct client access denied, and the signed iOS build is installed on
> a physical iPhone. The public API health check is available at
> <https://post-streak-api-rosst22.onrender.com/health>.

## Architecture

```text
iOS app + Share Extension
          │ Supabase access JWT
          ▼
      Render/FastAPI ──► Supabase Postgres
             │
             └──────► Supabase Auth JWKS (cached public signing keys)
```

FastAPI is the authorization boundary. It verifies every app-route JWT locally
against Supabase's asymmetric signing keys. `/health` is intentionally public for
Caddy and systemd monitoring. PostgreSQL Row Level Security is enabled and direct
Data API privileges are revoked from `anon` and `authenticated`.

## Security and privacy

- JWT signature, issuer, audience, expiry, role, and UUID subject are verified.
- Supabase secret keys stay server-side; iOS contains only the publishable key.
- Auth tokens live in an Apple Keychain group shared only by the two app targets.
- User-controlled URLs are stored but never fetched by the backend, avoiding SSRF.
- Displayed titles are normalized and filtered; SwiftUI renders them as text.
- Reports are unique per reporter/post. Blocking removes the friendship and filters
  both users from future feeds.
- Account deletion uses the Supabase Admin API and cascades through app data.
- Privacy manifests declare collected data. There are no ads, analytics SDKs,
  tracking domains, or cross-app tracking.

See [SECURITY.md](SECURITY.md) for private vulnerability reporting. Never put a
database password or Supabase secret key in the iOS configuration.

## Weekly streak definition

- Weeks run Monday 00:00 through Sunday 23:59:59 in the user's saved IANA timezone.
- UTC post timestamps are converted to that timezone in
  [`backend/app/streaks.py`](backend/app/streaks.py).
- A week qualifies after its post count reaches `weekly_target`.
- If this week is still below target, the streak through last week remains live;
  the user still has time to qualify.
- Backfilled posts recompute history and can fill a missing week.
- Several posts can satisfy a target but still add only one week to a streak.

`GET /me/stats` returns 53 zero-filled weekly buckets and 365 zero-filled local-day
buckets, both oldest first. This gives the iOS client stable arrays to render.

## Backend setup

Requires Python 3.12+ and a Supabase project using an asymmetric Auth signing key
(ES256 is recommended).

1. In Supabase's SQL editor, run the files in `backend/migrations/` in order.
2. Copy `backend/.env.example` to `backend/.env` and fill in:
   - `DATABASE_URL`: direct or session-pooler Postgres URL using the `asyncpg` scheme.
   - `SUPABASE_URL`: Supabase project URL.
   - `SUPABASE_SECRET_KEY`: server-only key used for account deletion.
   - `SUPPORT_EMAIL`: public safety/privacy contact shown on the legal pages.
3. Install and verify:

```bash
cd backend
python3 -m venv .venv
.venv/bin/pip install -e '.[dev]'
.venv/bin/pytest -q
.venv/bin/ruff check .
.venv/bin/uvicorn app.main:app --reload
```

The protected API is:

- `POST /posts`, `GET /posts`
- `GET /me/stats`, `DELETE /me`
- `GET /feed`
- `POST /friends/request`, `POST /friends/accept`, `POST /friends/block`, `GET /friends`
- `POST /posts/{post_id}/report`

All protected calls use `Authorization: Bearer <Supabase access token>`.

## iOS setup

Requires Xcode 26 (the project targets iOS 17+) and XcodeGen.

1. Edit `ios/Config.xcconfig` with the deployed API URL, Supabase URL, and Supabase
   publishable key. Publishable keys are designed for clients; never place a
   Supabase secret/service-role key here.
2. Generate the project:

```bash
cd ios
brew install xcodegen
xcodegen generate
open PostStreak.xcodeproj
```

3. In Xcode, choose your Apple Developer team for both targets. Ensure both retain
   the shared Keychain group `com.rosstoma.PostStreak.shared`; the Share Extension
   needs it to refresh and use the signed-in session.

Email confirmation affects sign-up behavior. If confirmation is enabled in
Supabase, the app asks the user to confirm by email and then sign in.

## Managed deployment (recommended)

The repository includes [`render.yaml`](render.yaml) for a Render Blueprint. It
deploys only the `backend/` directory, runs the health check at `/health`, and asks
for the two server-only values instead of storing them in Git:

- `DATABASE_URL`
- `SUPABASE_SECRET_KEY`

Create a Render Blueprint from this repository and supply those values in the
dashboard. The free instance is suitable for development, but it sleeps after an
idle period; use an always-on instance before App Store release.

## Ubuntu deployment (alternative)

The templates assume the checkout is `/opt/post-streak`, a locked-down service user
named `poststreak`, and Uvicorn bound only to `127.0.0.1:8001`.

```bash
sudo cp deploy/post-streak.service /etc/systemd/system/
sudo cp deploy/Caddyfile /etc/caddy/Caddyfile
sudo systemctl daemon-reload
sudo systemctl enable --now post-streak
sudo systemctl reload caddy
curl https://api.example.com/health
```

Before those commands, create `/etc/post-streak.env`, install the backend virtual
environment under `/opt/post-streak/backend`, replace `api.example.com`, and point
DNS at the VPS. Production migration and deployment are intentionally manual.

## Tests

The current backend suite covers timezone week boundaries, a still-open week,
backfilled posts, multiple posts in one week, local-day heatmap boundaries, and
invalid timestamps/timezones, plus title normalization and filtering. GitHub Actions
runs the tests and Ruff checks on every push.

## Résumé line

Built a SwiftUI publishing-cadence tracker with a two-tap workflow and iOS Share
Extension, backed by FastAPI, Supabase Auth/Postgres, timezone-correct weekly streaks,
and a managed cloud deployment.
