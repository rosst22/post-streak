from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import AuthenticatedUser
from app.database import get_session
from app.models import BlockedUser, Friendship, FriendshipStatus, Post, User
from app.schemas import Author, PostResponse

router = APIRouter(tags=["feed"])
Database = Annotated[AsyncSession, Depends(get_session)]


@router.get("/feed", response_model=list[PostResponse])
async def get_feed(
    user: AuthenticatedUser,
    session: Database,
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> list[PostResponse]:
    friend_ids = (
        select(Friendship.addressee_id.label("friend_id"))
        .where(
            Friendship.requester_id == user.id,
            Friendship.status == FriendshipStatus.accepted,
        )
        .union_all(
            select(Friendship.requester_id.label("friend_id")).where(
                Friendship.addressee_id == user.id,
                Friendship.status == FriendshipStatus.accepted,
            )
        )
        .subquery()
    )
    blocked_ids = (
        select(BlockedUser.blocked_id.label("user_id"))
        .where(BlockedUser.blocker_id == user.id)
        .union_all(
            select(BlockedUser.blocker_id.label("user_id")).where(BlockedUser.blocked_id == user.id)
        )
        .subquery()
    )
    rows = (
        await session.execute(
            select(Post, User)
            .join(User, User.id == Post.user_id)
            .where(Post.user_id.in_(select(friend_ids.c.friend_id)))
            .where(Post.user_id.not_in(select(blocked_ids.c.user_id)))
            .order_by(Post.posted_at.desc())
            .limit(limit)
            .offset(offset)
        )
    ).all()

    return [
        PostResponse(
            id=post.id,
            user_id=post.user_id,
            platform=post.platform,
            posted_at=post.posted_at,
            format=post.format,
            url=post.url,
            title=post.title,
            created_at=post.created_at,
            author=Author(id=author.id, display_name=author.display_name),
        )
        for post, author in rows
    ]
