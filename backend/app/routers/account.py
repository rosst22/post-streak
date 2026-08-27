from typing import Annotated

import httpx
from fastapi import APIRouter, Depends, HTTPException, status

from app.auth import AuthenticatedUser
from app.config import Settings, get_settings
from app.schemas import ActionResponse

router = APIRouter(prefix="/me", tags=["me"])


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
