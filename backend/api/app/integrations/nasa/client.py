"""NASA POWER Daily Point client.

NASA POWER (Prediction Of Worldwide Energy Resources), maintained by NASA
Langley Research Center: https://power.larc.nasa.gov. This is an open,
unauthenticated data API - a different access path from NASA Earthdata
(`Settings.nasa_earthdata_token`), which this endpoint does not use.

This module only retrieves and normalizes evidence. It never computes
agronomy - see `app/compute/agro.py` for that boundary.

The exact request shape, parameter names, response envelope (including
the `fill_value` sentinel and per-parameter units below) were confirmed
against a real NASA POWER response during this phase's development, not
assumed from memory: a live GET to
`/api/temporal/daily/point?parameters=PRECTOTCORR,T2M_MAX,T2M_MIN&community=AG&...&format=JSON&time-standard=LST`
returned HTTP 200 with `header.time_standard == "LST"`,
`header.fill_value == -999.0`, `parameters.PRECTOTCORR.units == "mm/day"`,
and `parameters.T2M_MAX.units == parameters.T2M_MIN.units == "C"`.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, date, datetime
from typing import Any

import httpx

DAILY_POINT_ENDPOINT = "/api/temporal/daily/point"

# Verified against a live NASA POWER response (see module docstring), not
# invented. Adding a parameter here requires the same verification.
DEFAULT_PARAMETERS: tuple[str, ...] = ("PRECTOTCORR", "T2M_MAX", "T2M_MIN")

# Maps a NASA POWER parameter short name to the PowerDailyRecord field it
# fills. Extending this to a new parameter (e.g. solar radiation) requires
# verifying that parameter's presence, units, and behavior against a real
# NASA POWER response first - see the module docstring's verification note.
_PARAMETER_FIELD_MAP: dict[str, str] = {
    "PRECTOTCORR": "precipitation_mm",
    "T2M_MAX": "tmax_c",
    "T2M_MIN": "tmin_c",
}

_LAT_MIN, _LAT_MAX = -90.0, 90.0
_LON_MIN, _LON_MAX = -180.0, 180.0


class NasaPowerError(Exception):
    """Base class for every error this client raises."""


class NasaPowerValidationError(NasaPowerError):
    """The request itself was invalid (bad coordinates/date range) -
    raised before any network call is made."""


class NasaPowerRequestError(NasaPowerError):
    """The HTTP request failed or NASA POWER returned a non-200 status."""


class NasaPowerResponseError(NasaPowerError):
    """NASA POWER returned 200 but the body could not be parsed into the
    shape this client expects."""


@dataclass(frozen=True, slots=True)
class PowerDailyRecord:
    """One day of NASA POWER evidence. A field is `None` when NASA POWER
    did not report a value for that day (absent parameter, or a value
    matching the response's own declared fill value) - never coerced to
    `0.0`."""

    date: date
    precipitation_mm: float | None
    tmax_c: float | None
    tmin_c: float | None


@dataclass(frozen=True, slots=True)
class NasaPowerProvenance:
    """Everything needed to answer "where did this number come from?"
    without re-deriving it from memory. Fields NASA POWER's response does
    not verifiably provide (resolution, latency, processing level) are
    simply absent rather than guessed."""

    provider: str
    dataset_id: str
    source_url: str
    """Always the real NASA POWER request URL that produced this
    evidence - even when `data_mode` is 'cache' or 'fixture', this is
    never replaced with a `file://` path. See `local_evidence_path`."""
    endpoint: str
    community: str
    parameters: tuple[str, ...]
    latitude: float
    longitude: float
    start_date: date
    end_date: date
    time_standard: str
    retrieved_at: datetime
    """Always the original NASA retrieval time - never re-stamped to
    "now" on a cache or fixture replay."""
    units: dict[str, str]
    raw_metadata: dict[str, Any]
    data_mode: str
    """'live' (this call hit the network), 'cache' (loaded from
    `power_cache.py`), or 'fixture' (loaded from a committed demo/test
    fixture). Set by the caller, not this client."""
    local_evidence_path: str | None = None
    """Where a 'cache' or 'fixture' response was actually read from on
    disk. `source_url` still means the original NASA request."""
    fixture_sha256: str | None = None
    """The manifest-verified SHA-256 of the fixture file, set only when
    `data_mode == 'fixture'`."""


@dataclass(frozen=True, slots=True)
class PowerDailyResponse:
    records: list[PowerDailyRecord]
    provenance: NasaPowerProvenance
    raw: dict[str, Any]
    """The untouched NASA JSON body, kept for the cache layer to persist
    verbatim and for debugging - never re-derived from the normalized
    records."""


class NasaPowerClient:
    """Thin async client for the NASA POWER Daily Point endpoint.

    Retrieves and normalizes evidence only; every value this client
    returns is either an observation NASA POWER actually reported or an
    explicit `None` for "not reported". It never invents a value.
    """

    def __init__(
        self,
        *,
        base_url: str,
        timeout_seconds: float,
        http_client: httpx.AsyncClient | None = None,
    ) -> None:
        self._base_url = base_url.rstrip("/")
        self._timeout_seconds = timeout_seconds
        self._owns_client = http_client is None
        self._client = http_client or httpx.AsyncClient()

    async def aclose(self) -> None:
        if self._owns_client:
            await self._client.aclose()

    async def __aenter__(self) -> NasaPowerClient:
        return self

    async def __aexit__(self, *exc_info: object) -> None:
        await self.aclose()

    async def fetch_daily_point(
        self,
        *,
        latitude: float,
        longitude: float,
        start: date,
        end: date,
        parameters: tuple[str, ...] | None = None,
        community: str = "AG",
    ) -> PowerDailyResponse:
        """Fetches one Daily Point request and returns normalized records
        plus provenance with `data_mode="live"`.

        Raises `NasaPowerValidationError` for a request this client can
        reject without touching the network, `NasaPowerRequestError` for
        a network/HTTP failure, and `NasaPowerResponseError` for a 200
        response this client cannot parse.
        """
        self._validate_request(latitude=latitude, longitude=longitude, start=start, end=end)
        resolved_parameters = parameters or DEFAULT_PARAMETERS

        query: dict[str, str | float] = {
            "parameters": ",".join(resolved_parameters),
            "community": community,
            "longitude": longitude,
            "latitude": latitude,
            "start": start.strftime("%Y%m%d"),
            "end": end.strftime("%Y%m%d"),
            "format": "JSON",
            "time-standard": "LST",
        }

        try:
            response = await self._client.get(
                f"{self._base_url}{DAILY_POINT_ENDPOINT}",
                params=query,
                timeout=self._timeout_seconds,
            )
        except httpx.HTTPError as exc:
            raise NasaPowerRequestError(f"NASA POWER request failed: {exc}") from exc

        if response.status_code != httpx.codes.OK:
            raise NasaPowerRequestError(
                f"NASA POWER returned HTTP {response.status_code} for "
                f"{response.request.url}: {response.text[:500]}"
            )

        try:
            payload = response.json()
        except ValueError as exc:
            raise NasaPowerResponseError("NASA POWER response was not valid JSON") from exc

        return self.parse_daily_point_response(
            payload,
            parameters=resolved_parameters,
            community=community,
            latitude=latitude,
            longitude=longitude,
            start=start,
            end=end,
            source_url=str(response.request.url),
            data_mode="live",
        )

    def parse_daily_point_response(
        self,
        payload: dict[str, Any],
        *,
        parameters: tuple[str, ...],
        community: str,
        latitude: float,
        longitude: float,
        start: date,
        end: date,
        source_url: str,
        data_mode: str,
        retrieved_at: datetime | None = None,
        local_evidence_path: str | None = None,
        fixture_sha256: str | None = None,
    ) -> PowerDailyResponse:
        """Normalizes a NASA POWER Daily Point JSON body (freshly fetched,
        cached, or loaded from a fixture) into typed records + provenance.

        Shared by the live path above and by `power_cache.py` when it
        replays a cached or fixture body, so both paths normalize
        identically.

        For a live call, `source_url`/`retrieved_at` describe this request
        itself. For a cache/fixture replay, the caller passes the
        *original* NASA `source_url` and `retrieved_at` it recorded at
        acquisition time - never `file://...` or "now" - and uses
        `local_evidence_path`/`fixture_sha256` to say where the replay
        actually came from.
        """
        try:
            parameter_series: dict[str, dict[str, float]] = payload["properties"]["parameter"]
            header: dict[str, Any] = payload["header"]
            parameter_metadata: dict[str, Any] = payload["parameters"]
        except (KeyError, TypeError) as exc:
            raise NasaPowerResponseError(
                f"NASA POWER response is missing an expected field: {exc}"
            ) from exc

        fill_value = header.get("fill_value")
        reported_time_standard = header.get("time_standard")
        if reported_time_standard is not None and reported_time_standard != "LST":
            # We always request LST explicitly; a different echoed value
            # means the response cannot be trusted to mean what we asked
            # for, so this is a hard parse failure, not a warning.
            raise NasaPowerResponseError(
                f"Requested time-standard=LST but NASA POWER echoed "
                f"'{reported_time_standard}'"
            )

        all_dates = self._date_range(start, end)
        records: list[PowerDailyRecord] = []
        for day in all_dates:
            values: dict[str, float | None] = {}
            for parameter_name, field_name in _PARAMETER_FIELD_MAP.items():
                if parameter_name not in parameters:
                    values[field_name] = None
                    continue
                series = parameter_series.get(parameter_name)
                if series is None:
                    values[field_name] = None
                    continue
                raw_value = series.get(day.strftime("%Y%m%d"))
                values[field_name] = self._normalize_value(raw_value, fill_value=fill_value)

            records.append(
                PowerDailyRecord(
                    date=day,
                    precipitation_mm=values["precipitation_mm"],
                    tmax_c=values["tmax_c"],
                    tmin_c=values["tmin_c"],
                )
            )

        units = {
            name: meta["units"]
            for name, meta in parameter_metadata.items()
            if isinstance(meta, dict) and "units" in meta
        }

        provenance = NasaPowerProvenance(
            provider="NASA POWER",
            dataset_id=str(header.get("title", "NASA/POWER Daily")),
            source_url=source_url,
            endpoint=DAILY_POINT_ENDPOINT,
            community=community,
            parameters=parameters,
            latitude=latitude,
            longitude=longitude,
            start_date=start,
            end_date=end,
            time_standard="LST",
            retrieved_at=retrieved_at or datetime.now(UTC),
            units=units,
            raw_metadata={"header": header},
            data_mode=data_mode,
            local_evidence_path=local_evidence_path,
            fixture_sha256=fixture_sha256,
        )
        return PowerDailyResponse(records=records, provenance=provenance, raw=payload)

    @staticmethod
    def _normalize_value(raw_value: Any, *, fill_value: float | None) -> float | None:
        if raw_value is None:
            return None
        try:
            value = float(raw_value)
        except (TypeError, ValueError):
            return None
        if fill_value is not None and value == float(fill_value):
            return None
        return value

    @staticmethod
    def _date_range(start: date, end: date) -> list[date]:
        from datetime import timedelta

        days = (end - start).days
        return [start + timedelta(days=offset) for offset in range(days + 1)]

    @staticmethod
    def _validate_request(*, latitude: float, longitude: float, start: date, end: date) -> None:
        if not _LAT_MIN <= latitude <= _LAT_MAX:
            raise NasaPowerValidationError(
                f"latitude {latitude} out of range [{_LAT_MIN}, {_LAT_MAX}]"
            )
        if not _LON_MIN <= longitude <= _LON_MAX:
            raise NasaPowerValidationError(
                f"longitude {longitude} out of range [{_LON_MIN}, {_LON_MAX}]"
            )
        if start > end:
            raise NasaPowerValidationError(f"start ({start}) must be <= end ({end})")
