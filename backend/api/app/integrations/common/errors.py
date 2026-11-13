"""Error hierarchy shared by every provider integration client.

Callers catch `IntegrationError` to handle "any provider problem" and the
subclasses to react to a specific failure class. Messages never contain
credentials - see `http.redact_url`.
"""

from __future__ import annotations


class IntegrationError(Exception):
    """Base class for every error an integration client raises."""

    def __init__(self, message: str, *, provider: str = "") -> None:
        super().__init__(message)
        self.provider = provider


class IntegrationValidationError(IntegrationError):
    """The request was invalid; raised before any network call."""


class IntegrationOfflineError(IntegrationError):
    """Offline mode is on, so no network call was attempted."""


class IntegrationCredentialsMissingError(IntegrationError):
    """The endpoint needs credentials that are not configured. Raised
    before any network call, so a missing key never produces a confusing
    401 from the provider."""


class IntegrationAuthError(IntegrationError):
    """The provider rejected the credentials (HTTP 401/403)."""


class IntegrationRequestError(IntegrationError):
    """Transport failure, or a non-success HTTP status after retries."""

    def __init__(
        self, message: str, *, provider: str = "", status_code: int | None = None
    ) -> None:
        super().__init__(message, provider=provider)
        self.status_code = status_code


class IntegrationResponseError(IntegrationError):
    """The provider answered 2xx but the body was not the expected shape."""
