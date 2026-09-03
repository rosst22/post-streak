# App Review Information — Notes

A physical-device recording will be attached to the App Review reply before resubmission. The
durable demo login is entered in the dedicated Sign-in required fields.

1. SCREEN RECORDING

The recording is captured on a physical iPhone 15 Pro running iOS 26.6 (23G71). It begins with launch
and shows registration, login, logging/deleting a post, profile and target settings, streak/heatmap,
friend requests, feed, reporting, blocking, Share Extension, legal links, sign-out, and deletion.

2. TESTED DEVICES AND OPERATING SYSTEMS

- iPhone 15 Pro, iOS 26.6 (23G71) — physical-device functional testing and recording.
- iPhone 17 simulator, iOS 26.5 — layout and end-to-end UI verification.

Post Streak is iPhone-only and requires iOS 17.0 or later.

3. FUNCTIONS, AUDIENCE, PROBLEM, AND VALUE

Post Streak is a publishing-cadence tracker for creators and anyone building a posting habit. It
tracks what users publish and when—not views, likes, followers, or engagement. Users set a weekly
target, log Instagram, TikTok, YouTube, or other posts in two taps or from the Share Extension, and
see streaks, progress, recent logs, and a 365-day heatmap. Private friend connections add optional
accountability. There are no ads, purchases, subscriptions, or paid content.

4. SETUP AND MAIN FEATURES

Use the non-expiring demo credentials in the Sign-in required fields. After login, Home contains
seeded activity. Tap Log a post, then a platform. Use the ellipsis beside a recent log to delete it.
Open Settings to edit the display name/weekly target or delete the account. Open Friends, then the
person-plus button, to view the friend code and manage requests. In the friends feed, use the visible
ellipsis beside a post to Report or Block. For the Share Extension, share any web URL from Safari and
choose “Log to Post Streak.” No sample files are required.

Sign-in is required to sync cadence data with the Share Extension and maintain private friendships.
Email is used only for authentication and is never shown to friends.

5. EXTERNAL SERVICES, TOOLS, AND PLATFORMS

- Supabase Auth/Postgres: authentication and app data.
- DigitalOcean: FastAPI backend and public legal/support pages.
- Apple Keychain/Share Extension: session storage and shared-link logging.
- Instagram, TikTok, and YouTube: labels/outbound destinations only; no APIs or credentials.

There are no analytics, advertising, payment, tracking, or AI services.

6. REGIONAL DIFFERENCES

None. Features and content are consistent in all regions. Weeks are Monday–Sunday and timestamps
use the user’s device timezone. The interface is currently English-only.

7. REGULATED INDUSTRY / THIRD-PARTY MATERIAL

Not applicable. This is a productivity tool, not a regulated service. It does not embed, copy, or
host protected media. Users may save outbound URLs to their own posts; platform names are descriptive.

SAFETY, PRIVACY, AND PERMISSIONS

Only accepted friends see a display name and logged link/title. Titles are filtered. Every feed item
has visible Report and Block actions; blocking removes the friendship. Reports are developer-reviewed
and support contact details are published in Settings. In-app deletion removes the Auth account and
associated data. No camera, microphone, location, contacts, photo-library, or ATT permission is used.
