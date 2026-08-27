"""Small, deterministic first-pass filter; reports still require human review."""

import re
import unicodedata

from fastapi import HTTPException, status

# The app stores cadence metadata, not the linked social content. This filter covers
# the only free-form field shown to friends. Keep phrases narrow to avoid surprising
# false positives; the report/block workflow handles context a word list cannot.
BLOCKED_PHRASES = (
    "kill yourself",
    "child sexual abuse",
    "racial supremacy",
    "sexual violence",
)


def validate_user_text(value: str | None) -> str | None:
    if value is None:
        return None
    cleaned = "".join(
        " " if unicodedata.category(character) == "Cc" else character for character in value
    )
    normalized = re.sub(r"\s+", " ", unicodedata.normalize("NFKC", cleaned)).strip()
    lowered = normalized.casefold()
    if any(phrase in lowered for phrase in BLOCKED_PHRASES):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="The title contains content that cannot be shared.",
        )
    return normalized or None
