from html import escape
from typing import Annotated

from fastapi import APIRouter, Depends
from fastapi.responses import HTMLResponse

from app.config import Settings, get_settings

router = APIRouter(tags=["legal"])


def page(title: str, body: str, support_email: str) -> HTMLResponse:
    safe_email = escape(support_email)
    return HTMLResponse(
        f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>{escape(title)} — Post Streak</title><style>
body{{font:17px -apple-system,BlinkMacSystemFont,sans-serif;line-height:1.55;max-width:720px;
margin:48px auto;padding:0 20px;color:#e5e7eb;background:#0b0d0c}}a{{color:#22c55e}}
h1,h2{{line-height:1.2}}small{{color:#9ca3af}}</style></head><body>
<h1>{escape(title)}</h1>{body}
<p>Contact: <a href="mailto:{safe_email}">{safe_email}</a></p>
<small>Last updated August 27, 2026</small></body></html>"""
    )


@router.get("/privacy", response_class=HTMLResponse)
async def privacy(settings: Annotated[Settings, Depends(get_settings)]) -> HTMLResponse:
    return page(
        "Privacy Policy",
        """<p>Post Streak collects the email address used for authentication, your display name,
timezone, weekly target, post cadence metadata, shared post links, and friendship/moderation data.
This information is used only to provide authentication, streak statistics, sharing, and the
friends feed.</p><h2>Sharing and tracking</h2><p>Data is processed by Supabase, our authentication
and database provider, and by the server hosting the API. We do not sell personal data, run ads,
or track users across apps or websites.</p><h2>Retention and deletion</h2><p>Data is retained while
your account exists. You can permanently delete your account and associated app data inside the
app under Settings. You may also contact support to request access or deletion.</p><h2>Safety</h2>
<p>Reports and blocks are stored so we can investigate abuse and protect users.</p>""",
        settings.support_email,
    )


@router.get("/terms", response_class=HTMLResponse)
async def terms(settings: Annotated[Settings, Depends(get_settings)]) -> HTMLResponse:
    return page(
        "Terms and Community Standards",
        """<p>Use Post Streak only for lawful publishing-cadence tracking. Do not submit spam,
harassment, hate speech, sexual exploitation, threats, or links to illegal or abusive material.
Users may report posts and block accounts. We may remove content or accounts that violate these
standards. You retain responsibility for and ownership of the links and titles you submit.</p>
<p>The service is provided as available without a promise of uninterrupted operation.</p>""",
        settings.support_email,
    )


@router.get("/support", response_class=HTMLResponse)
async def support(settings: Annotated[Settings, Depends(get_settings)]) -> HTMLResponse:
    return page(
        "Support",
        """<p>For account help, privacy requests, safety reports, or technical support, email us.
Safety reports are reviewed promptly. Include enough context to identify the issue, but do not
send passwords or authentication tokens.</p>""",
        settings.support_email,
    )
