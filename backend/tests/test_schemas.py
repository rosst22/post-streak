import pytest
from pydantic import ValidationError

from app.schemas import MeUpdate


def test_profile_update_normalizes_display_name() -> None:
    update = MeUpdate(
        display_name="  Demo   Creator  ",
        timezone="America/Toronto",
        weekly_target=5,
    )

    assert update.display_name == "Demo Creator"


@pytest.mark.parametrize(
    ("display_name", "weekly_target"),
    [("   ", 3), ("Creator", 0), ("Creator", 15)],
)
def test_profile_update_rejects_invalid_values(display_name: str, weekly_target: int) -> None:
    with pytest.raises(ValidationError):
        MeUpdate(
            display_name=display_name,
            timezone="America/Toronto",
            weekly_target=weekly_target,
        )
