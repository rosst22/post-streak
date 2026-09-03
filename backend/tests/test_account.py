import uuid

from app.auth import CurrentUser
from app.profiles import private_default_display_name


def user(email: object) -> CurrentUser:
    return CurrentUser(id=uuid.uuid4(), claims={"email": email})


def test_email_derived_default_becomes_private() -> None:
    assert private_default_display_name("ross.toma", user("ross.toma@gmail.com")) == "Creator"


def test_user_selected_display_name_is_preserved() -> None:
    assert private_default_display_name("Ross", user("ross.toma@gmail.com")) == "Ross"


def test_missing_or_invalid_email_preserves_name() -> None:
    assert private_default_display_name("Creator", user(None)) == "Creator"
