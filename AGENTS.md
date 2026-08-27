# AGENTS.md

## Product boundary

Post Streak tracks publishing output only: posts and cadence. Do not add views,
followers, likes, engagement, or other outcome metrics.

## Architecture

- `backend/`: FastAPI, async SQLAlchemy, Supabase Postgres and Auth.
- `backend/app/streaks.py`: the only place allowed to define calendar/streak rules.
- `backend/migrations/`: SQL applied in order through the Supabase SQL editor.
- `ios/`: SwiftUI app plus a UIKit Share Extension; `Shared/` belongs to both targets.
- `deploy/`: systemd and Caddy templates for Ubuntu.

## Commands

```bash
cd backend
python3 -m venv .venv
.venv/bin/pip install -e '.[dev]'
.venv/bin/pytest -q
.venv/bin/ruff check .

cd ../ios
xcodegen generate
xcodebuild -project PostStreak.xcodeproj -scheme PostStreak \
  -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```

## Rules

- Store timestamps as UTC-aware `timestamptz`; localize only in the streak module.
- Weeks are ISO Monday–Sunday weeks in the user's saved IANA timezone.
- The open current week does not break a previous live streak.
- Never trust a decoded JWT without verifying signature, issuer, audience and expiry.
- Both iOS targets must retain the same Keychain access group.
- Regenerate the Xcode project after editing `ios/project.yml`.
- Ask before applying production migrations or deploying.

