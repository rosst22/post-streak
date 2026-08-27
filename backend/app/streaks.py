"""The one canonical place for all local-calendar cadence calculations."""

from collections import Counter
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


@dataclass(frozen=True)
class WeekCount:
    week_start: date
    count: int


@dataclass(frozen=True)
class DayCount:
    date: date
    count: int


@dataclass(frozen=True)
class StreakStats:
    current_streak: int
    longest_streak: int
    current_week_posts: int
    posts_per_week: list[WeekCount]
    heatmap: list[DayCount]


def _week_start(value: date) -> date:
    """Return the Monday beginning value's ISO week."""
    return value - timedelta(days=value.weekday())


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        raise ValueError("post timestamps must be timezone-aware")
    return value.astimezone(UTC)


def calculate_streak_stats(
    posted_at: list[datetime],
    *,
    timezone: str,
    weekly_target: int,
    now: datetime | None = None,
    week_history: int = 53,
    heatmap_days: int = 365,
) -> StreakStats:
    """Calculate cadence using ISO weeks and local dates in ``timezone``.

    An incomplete current week does not break an existing streak because the user
    still has time to hit the target. Once the current week qualifies, it extends
    the streak. Historical/backfilled posts are treated exactly like timely posts.
    """
    if weekly_target < 1:
        raise ValueError("weekly_target must be at least 1")
    if week_history < 1 or heatmap_days < 1:
        raise ValueError("history lengths must be positive")

    try:
        tz = ZoneInfo(timezone)
    except ZoneInfoNotFoundError as exc:
        raise ValueError(f"unknown IANA timezone: {timezone}") from exc

    instant = _as_utc(now or datetime.now(UTC))
    today = instant.astimezone(tz).date()
    current_week = _week_start(today)

    local_dates = [_as_utc(timestamp).astimezone(tz).date() for timestamp in posted_at]
    daily_counts = Counter(local_dates)
    weekly_counts = Counter(_week_start(day) for day in local_dates)

    displayed_weeks = [
        current_week - timedelta(weeks=offset) for offset in range(week_history - 1, -1, -1)
    ]
    posts_per_week = [WeekCount(week, weekly_counts[week]) for week in displayed_weeks]

    displayed_days = [today - timedelta(days=offset) for offset in range(heatmap_days - 1, -1, -1)]
    heatmap = [DayCount(day, daily_counts[day]) for day in displayed_days]

    qualified = {week for week, count in weekly_counts.items() if count >= weekly_target}

    streak_end = current_week if current_week in qualified else current_week - timedelta(weeks=1)
    current_streak = 0
    cursor = streak_end
    while cursor in qualified:
        current_streak += 1
        cursor -= timedelta(weeks=1)

    longest_streak = 0
    running = 0
    previous: date | None = None
    for week in sorted(qualified):
        if previous is not None and week == previous + timedelta(weeks=1):
            running += 1
        else:
            running = 1
        longest_streak = max(longest_streak, running)
        previous = week

    return StreakStats(
        current_streak=current_streak,
        longest_streak=longest_streak,
        current_week_posts=weekly_counts[current_week],
        posts_per_week=posts_per_week,
        heatmap=heatmap,
    )
