from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import AuthenticatedUser
from app.database import get_session
from app.models import Post, User
from app.schemas import DayCount, StatsResponse, WeekCount
from app.streaks import calculate_streak_stats

router = APIRouter(prefix="/me", tags=["me"])
Database = Annotated[AsyncSession, Depends(get_session)]


@router.get("/stats", response_model=StatsResponse)
async def get_stats(user: AuthenticatedUser, session: Database) -> StatsResponse:
    profile = await session.get(User, user.id)
    if profile is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="User profile is missing; verify the auth-user database trigger",
        )

    timestamps = list(
        await session.scalars(
            select(Post.posted_at).where(Post.user_id == user.id).order_by(Post.posted_at)
        )
    )
    try:
        stats = calculate_streak_stats(
            timestamps,
            timezone=profile.timezone,
            weekly_target=profile.weekly_target,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)
        ) from exc

    return StatsResponse(
        current_streak=stats.current_streak,
        longest_streak=stats.longest_streak,
        weekly_target=profile.weekly_target,
        current_week_posts=stats.current_week_posts,
        posts_per_week=[
            WeekCount(week_start=item.week_start, count=item.count) for item in stats.posts_per_week
        ],
        heatmap=[DayCount(date=item.date, count=item.count) for item in stats.heatmap],
    )
