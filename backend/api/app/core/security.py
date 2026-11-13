"""Verify Firebase ID tokens before granting access to the API."""

import asyncio
import json
from dataclasses import dataclass

import firebase_admin
from fastapi import Header, HTTPException, status
from firebase_admin import auth, credentials
from jose import JWTError, jwt

from app.core.config import get_settings


@dataclass(frozen=True)
class TokenClaims:
    user_id: str
    email: str | None
    phone: str | None
    raw: dict


class InvalidTokenError(Exception):
    pass


def decode_supabase_jwt(token: str) -> TokenClaims:
    settings = get_settings()
    if not settings.supabase_jwt_secret:
        raise InvalidTokenError("SUPABASE_JWT_SECRET is not configured")

    try:
        payload = jwt.decode(
            token,
            settings.supabase_jwt_secret,
            algorithms=["HS256"],
            audience=settings.supabase_jwt_audience,
        )
    except JWTError as exc:
        raise InvalidTokenError(str(exc)) from exc

    subject = payload.get("sub")
    if not subject:
        raise InvalidTokenError("Token is missing a subject (sub) claim")

    return TokenClaims(
        user_id=subject,
        email=payload.get("email"),
        phone=payload.get("phone"),
        raw=payload,
    )


def decode_firebase_token(token: str) -> TokenClaims:
    settings = get_settings()
    if not settings.firebase_project_id or not settings.firebase_service_account_json:
        raise InvalidTokenError("Firebase is not configured")
    try:
        try:
            firebase_admin.get_app()
        except ValueError:
            firebase_admin.initialize_app(
                credentials.Certificate(json.loads(settings.firebase_service_account_json)),
                {"projectId": settings.firebase_project_id},
            )
        payload = auth.verify_id_token(token, check_revoked=True)
    except Exception as exc:
        raise InvalidTokenError("Firebase token verification failed") from exc
    if not payload.get("email") or not payload.get("email_verified"):
        raise InvalidTokenError("A verified email is required")
    return TokenClaims(
        user_id=payload["uid"],
        email=payload.get("email"),
        phone=payload.get("phone_number"),
        raw=payload,
    )


async def get_current_claims(
    authorization: str | None = Header(default=None),
) -> TokenClaims:
    """FastAPI dependency: extracts and verifies the bearer token.

    Raises 401 on any missing/invalid/expired token so callers never see a
    partially-trusted identity.
    """
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = authorization.split(" ", 1)[1].strip()
    try:
        if get_settings().auth_provider == "firebase":
            return await asyncio.to_thread(decode_firebase_token, token)
        if get_settings().auth_provider == "supabase":
            return decode_supabase_jwt(token)
        raise InvalidTokenError("Unknown authentication provider")
    except InvalidTokenError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {exc}",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc
