from datetime import UTC, datetime

import pytest

from app.streaks import calculate_streak_stats


def utc(year: int, month: int, day: int, hour: int = 12, minute: int = 0) -> datetime:
    return datetime(year, month, day, hour, minute, tzinfo=UTC)


def test_timezone_boundary_assigns_same_instants_to_different_local_weeks() -> None:
    # Sunday 23:30 in Los Angeles, but already Monday 06:30 UTC.
    post = utc(2026, 8, 31, 6, 30)
    now = utc(2026, 9, 1)

    los_angeles = calculate_streak_stats(
        [post], timezone="America/Los_Angeles", weekly_target=1, now=now
    )
    utc_stats = calculate_streak_stats([post], timezone="UTC", weekly_target=1, now=now)

    assert los_angeles.posts_per_week[-2].count == 1
    assert los_angeles.posts_per_week[-1].count == 0
    assert utc_stats.posts_per_week[-1].count == 1


def test_incomplete_current_week_does_not_break_previous_streak() -> None:
    stats = calculate_streak_stats(
        [utc(2026, 8, 17), utc(2026, 8, 24)],
        timezone="UTC",
        weekly_target=1,
        now=utc(2026, 9, 2),
    )

    assert stats.current_streak == 2
    assert stats.longest_streak == 2


def test_backfilled_post_recomputes_and_bridges_streak() -> None:
    now = utc(2026, 9, 2)
    without_backfill = calculate_streak_stats(
        [utc(2026, 8, 10), utc(2026, 8, 24)], timezone="UTC", weekly_target=1, now=now
    )
    with_backfill = calculate_streak_stats(
        [utc(2026, 8, 10), utc(2026, 8, 18), utc(2026, 8, 24)],
        timezone="UTC",
        weekly_target=1,
        now=now,
    )

    assert without_backfill.current_streak == 1
    assert with_backfill.current_streak == 3
    assert with_backfill.longest_streak == 3


def test_several_posts_in_one_week_count_once_toward_streak() -> None:
    stats = calculate_streak_stats(
        [
            utc(2026, 8, 24),
            utc(2026, 8, 25),
            utc(2026, 8, 26),
            utc(2026, 8, 31),
            utc(2026, 9, 1),
        ],
        timezone="UTC",
        weekly_target=2,
        now=utc(2026, 9, 2),
    )

    assert stats.current_week_posts == 2
    assert stats.current_streak == 2
    assert stats.longest_streak == 2


def test_heatmap_is_365_local_days_including_today() -> None:
    stats = calculate_streak_stats(
        [utc(2026, 9, 2, 3)],
        timezone="America/Toronto",
        weekly_target=1,
        now=utc(2026, 9, 2, 4),
    )

    assert len(stats.heatmap) == 365
    assert stats.heatmap[-1].date.isoformat() == "2026-09-02"
    assert stats.heatmap[-2].count == 1  # 03:00 UTC was 23:00 locally the day before.


def test_rejects_naive_timestamps_and_unknown_timezones() -> None:
    with pytest.raises(ValueError, match="timezone-aware"):
        calculate_streak_stats(
            [datetime(2026, 8, 24)], timezone="UTC", weekly_target=1, now=utc(2026, 9, 2)
        )
    with pytest.raises(ValueError, match="unknown IANA timezone"):
        calculate_streak_stats([], timezone="Mars/Olympus_Mons", weekly_target=1)
