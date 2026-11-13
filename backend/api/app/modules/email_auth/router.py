"""Short-lived email codes exchanged for Firebase custom tokens."""

import asyncio
import hashlib
import hmac
import json
import secrets
import smtplib
from email.message import EmailMessage

import firebase_admin
from fastapi import APIRouter, HTTPException
from firebase_admin import auth, credentials
from pydantic import BaseModel, EmailStr, Field

from app.core.config import get_settings
from app.core.redis import get_redis_client

router = APIRouter(prefix="/auth/email", tags=["email-auth"])


class EmailRequest(BaseModel):
    email: EmailStr
    mode: str = Field(pattern="^(register|login)$")


class VerifyRequest(EmailRequest):
    code: str = Field(pattern=r"^[0-9]{6}$")


def _firebase_app():
    settings = get_settings()
    if not settings.firebase_project_id or not settings.firebase_service_account_json:
        raise HTTPException(503, "Firebase Auth is not configured")
    try:
        return firebase_admin.get_app()
    except ValueError:
        credential = credentials.Certificate(json.loads(settings.firebase_service_account_json))
        return firebase_admin.initialize_app(
            credential, {"projectId": settings.firebase_project_id}
        )


def _key(email: str, mode: str) -> str:
    return "email_otp:" + hashlib.sha256(f"{mode}:{email}".encode()).hexdigest()


def _digest(email: str, mode: str, code: str) -> str:
    secret = get_settings().otp_hmac_secret
    if not secret:
        raise HTTPException(503, "OTP secret is not configured")
    return hmac.new(secret.encode(), f"{mode}:{email}:{code}".encode(), hashlib.sha256).hexdigest()


def _send_email(email: str, code: str) -> None:
    settings = get_settings()
    message = EmailMessage()
    message["From"] = settings.smtp_from_email
    message["To"] = email
    message["Subject"] = "AgriGuardian verification code"
    message.set_content(f"Your AgriGuardian code is {code}. It expires in 10 minutes. If you did not request it, ignore this email.")
    if settings.smtp_port == 465:
        with smtplib.SMTP_SSL(settings.smtp_host, settings.smtp_port, timeout=15) as smtp:
            if settings.smtp_username and settings.smtp_password:
                smtp.login(settings.smtp_username, settings.smtp_password)
            smtp.send_message(message)
    else:
        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=15) as smtp:
            smtp.starttls()
            if settings.smtp_username and settings.smtp_password:
                smtp.login(settings.smtp_username, settings.smtp_password)
            smtp.send_message(message)


@router.post("/request")
async def request_code(body: EmailRequest):
    settings = get_settings()
    _firebase_app()
    if not all((settings.smtp_host, settings.smtp_username, settings.smtp_password, settings.smtp_from_email)):
        raise HTTPException(503, "Email delivery is not configured")
    email = str(body.email).strip().lower()
    try:
        existing = await asyncio.to_thread(auth.get_user_by_email, email)
    except auth.UserNotFoundError:
        existing = None
    if body.mode == "register" and existing is not None:
        raise HTTPException(409, "Account already exists; log in instead")
    if body.mode == "login" and existing is None:
        raise HTTPException(404, "Account not found; create one first")
    redis = get_redis_client()
    key = _key(email, body.mode)
    cooldown_key = f"{key}:cooldown"
    if not await redis.set(cooldown_key, "1", ex=60, nx=True):
        raise HTTPException(429, "Please wait before requesting another code")
    code = f"{secrets.randbelow(1000000):06d}"
    # The code is stored only as a keyed digest. Redis expires it automatically.
    await redis.hset(key, mapping={"digest": _digest(email, body.mode, code), "attempts": 0})
    await redis.expire(key, 600)
    try:
        await asyncio.to_thread(_send_email, email, code)
    except (OSError, smtplib.SMTPException):
        await redis.delete(key)
        await redis.delete(cooldown_key)
        raise HTTPException(503, "Could not send verification email") from None
    return {"sent": True}


_VERIFY_SCRIPT = """
local expected = redis.call('HGET', KEYS[1], 'digest')
if not expected then return 0 end
local attempts = tonumber(redis.call('HGET', KEYS[1], 'attempts') or '0')
if attempts >= 5 then redis.call('DEL', KEYS[1]); return -1 end
if expected ~= ARGV[1] then
  attempts = redis.call('HINCRBY', KEYS[1], 'attempts', 1)
  if attempts >= 5 then redis.call('DEL', KEYS[1]) end
  return 0
end
redis.call('DEL', KEYS[1])
return 1
"""


@router.post("/verify")
async def verify_code(body: VerifyRequest):
    _firebase_app()
    email = str(body.email).strip().lower()
    result = await get_redis_client().eval(
        _VERIFY_SCRIPT, 1, _key(email, body.mode), _digest(email, body.mode, body.code)
    )
    if result != 1:
        raise HTTPException(400, "Invalid or expired code")
    if body.mode == "register":
        try:
            user = await asyncio.to_thread(auth.create_user, email=email, email_verified=True)
        except auth.EmailAlreadyExistsError:
            raise HTTPException(409, "Account already exists; log in instead") from None
    else:
        try:
            user = await asyncio.to_thread(auth.get_user_by_email, email)
        except auth.UserNotFoundError:
            raise HTTPException(404, "Account not found") from None
    token = await asyncio.to_thread(auth.create_custom_token, user.uid)
    return {"firebase_token": token.decode() if isinstance(token, bytes) else token}
