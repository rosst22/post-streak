import pytest
from fastapi import HTTPException

from app.moderation import validate_user_text


def test_normalizes_title_before_storage() -> None:
    assert validate_user_text("  New\n\tvideo!  ") == "New video!"


def test_rejects_clearly_objectionable_title() -> None:
    with pytest.raises(HTTPException) as exc_info:
        validate_user_text("You should KILL   YOURSELF")

    assert exc_info.value.status_code == 422
