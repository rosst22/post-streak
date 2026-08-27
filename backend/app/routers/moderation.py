import uuid
from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import AuthenticatedUser
from app.database import get_session
from app.models import Post, PostReport
from app.schemas import ActionResponse, ContentReportCreate

router = APIRouter(prefix="/posts", tags=["moderation"])
Database = Annotated[AsyncSession, Depends(get_session)]


@router.post(
    "/{post_id}/report",
    response_model=ActionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def report_post(
    post_id: uuid.UUID,
    body: ContentReportCreate,
    user: AuthenticatedUser,
    session: Database,
) -> ActionResponse:
    post = await session.scalar(select(Post).where(Post.id == post_id))
    if post is None:
        raise HTTPException(status_code=404, detail="Post not found")
    if post.user_id == user.id:
        raise HTTPException(status_code=422, detail="You cannot report your own post")

    session.add(
        PostReport(
            id=uuid.uuid4(),
            reporter_id=user.id,
            post_id=post.id,
            reason=body.reason,
            details=body.details,
            status="open",
            created_at=datetime.now(UTC),
        )
    )
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        raise HTTPException(status_code=409, detail="You already reported this post") from None
    return ActionResponse(message="Report received")
