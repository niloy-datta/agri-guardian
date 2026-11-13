"""Tests for the Firebase email OTP authentication module."""

from unittest.mock import MagicMock, patch

import pytest
from fastapi import HTTPException
from firebase_admin import auth

from app.core.config import Settings
from app.core.security import InvalidTokenError, TokenClaims, decode_firebase_token
from app.modules.email_auth.router import (
    EmailRequest,
    VerifyRequest,
    _digest,
    _key,
    request_code,
    verify_code,
)


@pytest.fixture(autouse=True)
def clean_tables():
    """Override autouse DB fixture to allow pure unit testing without PostgreSQL."""
    pass


@pytest.fixture
def auth_settings():
    return Settings(
        auth_provider="firebase",
        firebase_project_id="test-agri-project",
        firebase_service_account_json='{"type": "service_account", "project_id": "test-agri-project"}',
        otp_hmac_secret="test-super-secret-hmac-key",
        smtp_host="smtp.example.com",
        smtp_port=587,
        smtp_username="smtp-user",
        smtp_password="smtp-password",
        smtp_from_email="no-reply@agriguardian.org",
    )


class FakeRedis:
    def __init__(self):
        self.store = {}
        self.hashes = {}
        self.ttls = {}

    async def set(self, key, value, ex=None, nx=False):
        if nx and key in self.store:
            return None
        self.store[key] = value
        if ex:
            self.ttls[key] = ex
        return True

    async def hset(self, key, mapping=None):
        if key not in self.hashes:
            self.hashes[key] = {}
        if mapping:
            self.hashes[key].update(mapping)
        return len(mapping) if mapping else 0

    async def expire(self, key, seconds):
        self.ttls[key] = seconds
        return True

    async def delete(self, *keys):
        count = 0
        for k in keys:
            if k in self.store:
                del self.store[k]
                count += 1
            if k in self.hashes:
                del self.hashes[k]
                count += 1
        return count

    async def eval(self, script, numkeys, key, digest):
        h = self.hashes.get(key)
        if not h:
            return 0
        attempts = int(h.get("attempts", 0))
        if attempts >= 5:
            self.hashes.pop(key, None)
            return -1
        if h.get("digest") != digest:
            attempts += 1
            h["attempts"] = attempts
            if attempts >= 5:
                self.hashes.pop(key, None)
            return 0
        self.hashes.pop(key, None)
        return 1


class TestEmailAuthHelpers:
    def test_key_generation(self):
        k1 = _key("farmer@example.com", "login")
        k2 = _key("farmer@example.com", "register")
        k3 = _key("farmer@example.com", "login")
        assert k1.startswith("email_otp:")
        assert k1 == k3
        assert k1 != k2

    def test_digest_deterministic_and_salted(self, auth_settings):
        with patch("app.modules.email_auth.router.get_settings", return_value=auth_settings):
            d1 = _digest("farmer@example.com", "login", "123456")
            d2 = _digest("farmer@example.com", "login", "123456")
            d3 = _digest("farmer@example.com", "login", "654321")
            assert d1 == d2
            assert d1 != d3


class TestRequestCodeEndpoint:
    @pytest.mark.asyncio
    async def test_fails_when_firebase_unconfigured(self):
        settings = Settings(firebase_project_id="", firebase_service_account_json="")
        with patch("app.modules.email_auth.router.get_settings", return_value=settings):
            with pytest.raises(HTTPException) as exc_info:
                await request_code(EmailRequest(email="farmer@example.com", mode="login"))
            assert exc_info.value.status_code == 503

    @pytest.mark.asyncio
    async def test_fails_when_smtp_unconfigured(self, auth_settings):
        auth_settings.smtp_host = ""
        with (
            patch("app.modules.email_auth.router.get_settings", return_value=auth_settings),
            patch("app.modules.email_auth.router._firebase_app"),
            pytest.raises(HTTPException) as exc_info,
        ):
            await request_code(EmailRequest(email="farmer@example.com", mode="login"))
        assert exc_info.value.status_code == 503

    @pytest.mark.asyncio
    async def test_register_mode_rejects_existing_user(self, auth_settings):
        mock_user = MagicMock(uid="user_123")
        with (
            patch("app.modules.email_auth.router.get_settings", return_value=auth_settings),
            patch("app.modules.email_auth.router._firebase_app"),
            patch("asyncio.to_thread", return_value=mock_user),
        ):
            with pytest.raises(HTTPException) as exc_info:
                await request_code(EmailRequest(email="existing@example.com", mode="register"))
            assert exc_info.value.status_code == 409

    @pytest.mark.asyncio
    async def test_login_mode_rejects_nonexistent_user(self, auth_settings):
        async def fake_get_user(fn, *args, **kwargs):
            if fn == auth.get_user_by_email:
                raise auth.UserNotFoundError("User not found")
            return None

        with (
            patch("app.modules.email_auth.router.get_settings", return_value=auth_settings),
            patch("app.modules.email_auth.router._firebase_app"),
            patch("asyncio.to_thread", side_effect=fake_get_user),
        ):
            with pytest.raises(HTTPException) as exc_info:
                await request_code(EmailRequest(email="missing@example.com", mode="login"))
            assert exc_info.value.status_code == 404

    @pytest.mark.asyncio
    async def test_rate_limit_cooldown(self, auth_settings):
        fake_redis = FakeRedis()
        mock_user = MagicMock(uid="user_123")

        with (
            patch("app.modules.email_auth.router.get_settings", return_value=auth_settings),
            patch("app.modules.email_auth.router._firebase_app"),
            patch("app.modules.email_auth.router.get_redis_client", return_value=fake_redis),
            patch("app.modules.email_auth.router._send_email"),
            patch("asyncio.to_thread", return_value=mock_user),
        ):
            # First request succeeds
            res = await request_code(EmailRequest(email="farmer@example.com", mode="login"))
            assert res == {"sent": True}

            # Second request within cooldown triggers 429
            with pytest.raises(HTTPException) as exc_info:
                await request_code(EmailRequest(email="farmer@example.com", mode="login"))
            assert exc_info.value.status_code == 429


class TestVerifyCodeEndpoint:
    @pytest.mark.asyncio
    async def test_verify_code_success_login(self, auth_settings):
        fake_redis = FakeRedis()
        email = "farmer@example.com"
        mode = "login"
        code = "123456"

        with patch("app.modules.email_auth.router.get_settings", return_value=auth_settings):
            digest = _digest(email, mode, code)
            fake_redis.hashes[_key(email, mode)] = {"digest": digest, "attempts": 0}

            mock_user = MagicMock(uid="uid_firebase_123")
            token_mock = b"custom_token_abc"

            async def fake_thread(fn, *args, **kwargs):
                if fn == auth.get_user_by_email:
                    return mock_user
                if fn == auth.create_custom_token:
                    return token_mock
                return None

            with (
                patch("app.modules.email_auth.router._firebase_app"),
                patch("app.modules.email_auth.router.get_redis_client", return_value=fake_redis),
                patch("asyncio.to_thread", side_effect=fake_thread),
            ):
                result = await verify_code(VerifyRequest(email=email, mode=mode, code=code))
                assert result == {"firebase_token": "custom_token_abc"}

    @pytest.mark.asyncio
    async def test_verify_code_invalid(self, auth_settings):
        fake_redis = FakeRedis()
        email = "farmer@example.com"
        mode = "login"
        correct_code = "123456"

        with patch("app.modules.email_auth.router.get_settings", return_value=auth_settings):
            digest = _digest(email, mode, correct_code)
            fake_redis.hashes[_key(email, mode)] = {"digest": digest, "attempts": 0}

            with (
                patch("app.modules.email_auth.router._firebase_app"),
                patch("app.modules.email_auth.router.get_redis_client", return_value=fake_redis),
            ):
                with pytest.raises(HTTPException) as exc_info:
                    await verify_code(VerifyRequest(email=email, mode=mode, code="999999"))
                assert exc_info.value.status_code == 400


class TestSecurityDecodeToken:
    def test_decode_firebase_token_success(self, auth_settings):
        payload = {
            "uid": "user_456",
            "email": "verified@example.com",
            "email_verified": True,
            "phone_number": "+8801700000000",
        }
        with (
            patch("app.core.security.get_settings", return_value=auth_settings),
            patch("firebase_admin.get_app"),
            patch("firebase_admin.auth.verify_id_token", return_value=payload),
        ):
            claims = decode_firebase_token("fake_valid_jwt")
            assert isinstance(claims, TokenClaims)
            assert claims.user_id == "user_456"
            assert claims.email == "verified@example.com"
            assert claims.phone == "+8801700000000"

    def test_decode_firebase_token_rejects_unverified_email(self, auth_settings):
        payload = {
            "uid": "user_456",
            "email": "unverified@example.com",
            "email_verified": False,
        }
        with (
            patch("app.core.security.get_settings", return_value=auth_settings),
            patch("firebase_admin.get_app"),
            patch("firebase_admin.auth.verify_id_token", return_value=payload),
            pytest.raises(InvalidTokenError),
        ):
            decode_firebase_token("fake_jwt")
