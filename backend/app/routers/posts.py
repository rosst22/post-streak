import uuid
from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import AuthenticatedUser
from app.database import get_session
from app.models import Post
from app.moderation import validate_user_text
from app.schemas import ActionResponse, PostCreate, PostResponse

router = APIRouter(prefix="/posts", tags=["posts"])
Database = Annotated[AsyncSession, Depends(get_session)]


@router.post("", response_model=PostResponse, status_code=status.HTTP_201_CREATED)
async def create_post(body: PostCreate, user: AuthenticatedUser, session: Database) -> Post:
    posted_at = body.posted_at or datetime.now(UTC)
    if posted_at.tzinfo is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="posted_at must include a UTC offset",
        )

    post = Post(
        id=uuid.uuid4(),
        user_id=user.id,
        platform=body.platform,
        posted_at=posted_at.astimezone(UTC),
        format=body.format,
        url=str(body.url) if body.url else None,
        title=validate_user_text(body.title),
        created_at=datetime.now(UTC),
    )
    session.add(post)
    await session.commit()
    await session.refresh(post)
    return post


@router.get("", response_model=list[PostResponse])
async def list_posts(
    user: AuthenticatedUser,
    session: Database,
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> list[Post]:
    result = await session.scalars(
        select(Post)
        .where(Post.user_id == user.id)
        .order_by(Post.posted_at.desc())
        .limit(limit)
        .offset(offset)
    )
    return list(result)


@router.delete("/{post_id}", response_model=ActionResponse)
async def delete_post(
    post_id: uuid.UUID,
    user: AuthenticatedUser,
    session: Database,
) -> ActionResponse:
    result = await session.execute(
        delete(Post).where(Post.id == post_id, Post.user_id == user.id)
    )
    if result.rowcount == 0:
        raise HTTPException(status_code=404, detail="Post not found")
    await session.commit()
    return ActionResponse(message="Post deleted")
