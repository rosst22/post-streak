from app.auth import CurrentUser


def private_default_display_name(display_name: str, user: CurrentUser) -> str:
    """Replace the old trigger's email-derived default without exposing email."""
    email = user.claims.get("email")
    if not isinstance(email, str) or "@" not in email:
        return display_name
    email_prefix = email.split("@", 1)[0]
    return "Creator" if display_name.casefold() == email_prefix.casefold() else display_name
