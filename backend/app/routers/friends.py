import uuid
from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import delete, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import AuthenticatedUser
from app.database import get_session
from app.models import BlockedUser, Friendship, FriendshipStatus, User
from app.schemas import (
    ActionResponse,
    BlockUserCreate,
    FriendAcceptCreate,
    FriendRequestCreate,
    FriendResponse,
)

router = APIRouter(prefix="/friends", tags=["friends"])
Database = Annotated[AsyncSession, Depends(get_session)]


@router.post("/request", response_model=FriendResponse, status_code=status.HTTP_201_CREATED)
async def request_friend(
    body: FriendRequestCreate, user: AuthenticatedUser, session: Database
) -> FriendResponse:
    addressee = await session.scalar(
        select(User).where(User.friend_code == body.friend_code.lower())
    )
    if addressee is None:
        raise HTTPException(status_code=404, detail="Friend code not found")
    if addressee.id == user.id:
        raise HTTPException(status_code=422, detail="You cannot friend yourself")
    blocked = await session.scalar(
        select(BlockedUser).where(
            or_(
                (BlockedUser.blocker_id == user.id) & (BlockedUser.blocked_id == addressee.id),
                (BlockedUser.blocker_id == addressee.id) & (BlockedUser.blocked_id == user.id),
            )
        )
    )
    if blocked is not None:
        raise HTTPException(status_code=409, detail="This friendship is unavailable")

    friendship = Friendship(
        id=uuid.uuid4(),
        requester_id=user.id,
        addressee_id=addressee.id,
        status=FriendshipStatus.pending,
        created_at=datetime.now(UTC),
        updated_at=datetime.now(UTC),
    )
    session.add(friendship)
    try:
        await session.commit()
    except IntegrityError:
        await session.rollback()
        raise HTTPException(status_code=409, detail="A friendship already exists") from None

    return FriendResponse(
        friendship_id=friendship.id,
        user_id=addressee.id,
        display_name=addressee.display_name,
        status=friendship.status,
        direction="outgoing",
    )


@router.post("/accept", response_model=FriendResponse)
async def accept_friend(
    body: FriendAcceptCreate, user: AuthenticatedUser, session: Database
) -> FriendResponse:
    friendship = await session.scalar(
        select(Friendship)
        .where(
            Friendship.id == body.friendship_id,
            Friendship.addressee_id == user.id,
            Friendship.status == FriendshipStatus.pending,
        )
        .with_for_update()
    )
    if friendship is None:
        raise HTTPException(status_code=404, detail="Pending incoming request not found")

    friendship.status = FriendshipStatus.accepted
    friendship.updated_at = datetime.now(UTC)
    requester = await session.get(User, friendship.requester_id)
    if requester is None:
        raise HTTPException(status_code=409, detail="Requester profile is missing")
    await session.commit()

    return FriendResponse(
        friendship_id=friendship.id,
        user_id=requester.id,
        display_name=requester.display_name,
        status=friendship.status,
        direction="incoming",
    )


@router.get("", response_model=list[FriendResponse])
async def list_friends(user: AuthenticatedUser, session: Database) -> list[FriendResponse]:
    blocked_ids = set(
        await session.scalars(
            select(BlockedUser.blocked_id).where(BlockedUser.blocker_id == user.id)
        )
    )
    blocked_ids.update(
        await session.scalars(
            select(BlockedUser.blocker_id).where(BlockedUser.blocked_id == user.id)
        )
    )
    friendships = list(
        await session.scalars(
            select(Friendship)
            .where(or_(Friendship.requester_id == user.id, Friendship.addressee_id == user.id))
            .order_by(Friendship.updated_at.desc())
        )
    )
    other_ids = {
        item.addressee_id if item.requester_id == user.id else item.requester_id
        for item in friendships
    } - blocked_ids
    people = {
        person.id: person
        for person in (
            list(await session.scalars(select(User).where(User.id.in_(other_ids))))
            if other_ids
            else []
        )
    }

    return [
        FriendResponse(
            friendship_id=item.id,
            user_id=other_id,
            display_name=people[other_id].display_name,
            status=item.status,
            direction="outgoing" if item.requester_id == user.id else "incoming",
        )
        for item in friendships
        if (other_id := item.addressee_id if item.requester_id == user.id else item.requester_id)
        in people
    ]


@router.post("/block", response_model=ActionResponse)
async def block_user(
    body: BlockUserCreate, user: AuthenticatedUser, session: Database
) -> ActionResponse:
    if body.user_id == user.id:
        raise HTTPException(status_code=422, detail="You cannot block yourself")
    if await session.get(User, body.user_id) is None:
        raise HTTPException(status_code=404, detail="User not found")

    existing = await session.get(BlockedUser, (user.id, body.user_id))
    if existing is None:
        session.add(
            BlockedUser(
                blocker_id=user.id,
                blocked_id=body.user_id,
                created_at=datetime.now(UTC),
            )
        )
    await session.execute(
        delete(Friendship).where(
            or_(
                (Friendship.requester_id == user.id) & (Friendship.addressee_id == body.user_id),
                (Friendship.requester_id == body.user_id) & (Friendship.addressee_id == user.id),
            )
        )
    )
    await session.commit()
    return ActionResponse(message="User blocked")
