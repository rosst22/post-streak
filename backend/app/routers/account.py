from typing import Annotated

import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import AuthenticatedUser
from app.config import Settings, get_settings
from app.database import get_session
from app.models import User
from app.schemas import ActionResponse, MeResponse

router = APIRouter(prefix="/me", tags=["me"])


@router.get("", response_model=MeResponse)
async def get_me(
    user: AuthenticatedUser,
    session: Annotated[AsyncSession, Depends(get_session)],
) -> MeResponse:
    profile = await session.get(User, user.id)
    if profile is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
    return MeResponse(
        id=profile.id,
        display_name=profile.display_name,
        friend_code=profile.friend_code,
        timezone=profile.timezone,
        weekly_target=profile.weekly_target,
    )


@router.delete("", response_model=ActionResponse)
async def delete_account(
    user: AuthenticatedUser,
    settings: Annotated[Settings, Depends(get_settings)],
) -> ActionResponse:
    secret = settings.supabase_secret_key.get_secret_value()
    url = f"{str(settings.supabase_url).rstrip('/')}/auth/v1/admin/users/{user.id}"
    async with httpx.AsyncClient(timeout=15) as client:
        response = await client.delete(
            url,
            headers={"apikey": secret, "Authorization": f"Bearer {secret}"},
        )
    if response.status_code not in (200, 204):
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Account deletion failed. Contact support if this continues.",
        )
    return ActionResponse(message="Account and associated data deleted")
