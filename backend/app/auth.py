import asyncio
import uuid
from dataclasses import dataclass
from typing import Annotated, Any

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import PyJWKClient

from app.config import Settings, get_settings

bearer = HTTPBearer(auto_error=False)
_jwks_clients: dict[str, PyJWKClient] = {}


@dataclass(frozen=True)
class CurrentUser:
    id: uuid.UUID
    claims: dict[str, Any]


def _jwks_client(url: str) -> PyJWKClient:
    if url not in _jwks_clients:
        _jwks_clients[url] = PyJWKClient(url, cache_jwk_set=True, lifespan=600)
    return _jwks_clients[url]


def _decode_token(token: str, settings: Settings) -> dict[str, Any]:
    key = _jwks_client(settings.jwks_url).get_signing_key_from_jwt(token)
    return jwt.decode(
        token,
        key.key,
        algorithms=["ES256", "RS256"],
        audience="authenticated",
        issuer=settings.issuer,
        options={"require": ["exp", "sub", "role"]},
    )


async def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> CurrentUser:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        # PyJWKClient performs a cached network lookup. A worker thread prevents it
        # from blocking FastAPI's async event loop on the occasional cache miss.
        claims = await asyncio.to_thread(_decode_token, credentials.credentials, settings)
        if claims.get("role") != "authenticated":
            raise jwt.InvalidTokenError("token role is not authenticated")
        user_id = uuid.UUID(claims["sub"])
    except (jwt.PyJWTError, KeyError, TypeError, ValueError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from None

    return CurrentUser(id=user_id, claims=claims)


AuthenticatedUser = Annotated[CurrentUser, Depends(get_current_user)]
