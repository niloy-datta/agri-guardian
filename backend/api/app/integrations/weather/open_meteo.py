"""Open-Meteo Forecast, Historical (archive) and Flood clients.

Response envelope confirmed against live responses: top-level
`latitude/longitude/elevation/timezone/utc_offset_seconds`, a
`daily_units` / `hourly_units` map, and a `daily` / `hourly` object of
parallel arrays led by `time`. Errors come back as HTTP 400 with
`{"error": true, "reason": "..."}`.

Notes verified live:
- the API snaps the request to its own grid (a request for 24.37N 88.6E
  came back as 24.3585N 88.5608E; the flood grid is coarser, 24.375N
  88.625E). The *snapped* coordinates are returned so callers never
  mistake them for the field location.
- null entries inside the arrays are kept as `None`, never 0.

The free tier is for non-commercial use; set `open_meteo_api_key` (and
point the URLs at the `customer-` hosts) for commercial deployments.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import date, datetime
from typing import Any

from app.integrations.common.errors import (
    IntegrationResponseError,
    IntegrationValidationError,
)
from app.integrations.common.geo import validate_date_range, validate_lat_lon
from app.integrations.common.http import Provenance, ProviderHttp

PROVIDER = "Open-Meteo"
_VAR_RE = re.compile(r"^[a-z0-9_]+(_\d+m|_\d+_to_\d+cm|_\d+hPa)?$")

DEFAULT_FORECAST_DAILY = (
    "precipitation_sum",
    "temperature_2m_max",
    "temperature_2m_min",
    "et0_fao_evapotranspiration",
)
DEFAULT_FLOOD_DAILY = ("river_discharge",)


@dataclass(frozen=True, slots=True)
class WeatherRow:
    """One timestamp (a date for `daily`, a datetime for `hourly`)."""

    time: date | datetime
    values: dict[str, float | None]


@dataclass(frozen=True, slots=True)
class WeatherResult:
    rows: list[WeatherRow]
    units: dict[str, str]
    requested_latitude: float
    requested_longitude: float
    grid_latitude: float
    grid_longitude: float
    elevation_m: float | None
    timezone: str | None
    provenance: Provenance
    raw: dict[str, Any] = field(repr=False)


class OpenMeteoClient:
    def __init__(
        self,
        *,
        http: ProviderHttp,
        forecast_url: str,
        archive_url: str,
        flood_url: str,
        api_key: str = "",
    ) -> None:
        self._http = http
        self._forecast_url = forecast_url
        self._archive_url = archive_url
        self._flood_url = flood_url
        self._api_key = api_key

    async def forecast(
        self,
        *,
        latitude: float,
        longitude: float,
        daily: tuple[str, ...] = DEFAULT_FORECAST_DAILY,
        hourly: tuple[str, ...] = (),
        forecast_days: int = 7,
        past_days: int = 0,
        timezone: str = "Asia/Dhaka",
    ) -> WeatherResult:
        """Forecast for irrigation / spray planning. 1-16 forecast days."""
        if not 1 <= forecast_days <= 16:
            raise IntegrationValidationError("forecast_days must be 1-16", provider=PROVIDER)
        if not 0 <= past_days <= 92:
            raise IntegrationValidationError("past_days must be 0-92", provider=PROVIDER)
        return await self._fetch(
            self._forecast_url,
            dataset="Open-Meteo Forecast",
            latitude=latitude,
            longitude=longitude,
            daily=daily,
            hourly=hourly,
            timezone=timezone,
            extra={"forecast_days": forecast_days, "past_days": past_days},
        )

    async def historical(
        self,
        *,
        latitude: float,
        longitude: float,
        start: date,
        end: date,
        daily: tuple[str, ...] = ("precipitation_sum", "temperature_2m_max", "temperature_2m_min"),
        hourly: tuple[str, ...] = (),
        timezone: str = "Asia/Dhaka",
    ) -> WeatherResult:
        """Reanalysis archive, used to cross-check NASA POWER / IMERG rainfall."""
        validate_date_range(start, end, provider=PROVIDER)
        return await self._fetch(
            self._archive_url,
            dataset="Open-Meteo Historical Weather",
            latitude=latitude,
            longitude=longitude,
            daily=daily,
            hourly=hourly,
            timezone=timezone,
            extra={"start_date": start.isoformat(), "end_date": end.isoformat()},
        )

    async def flood(
        self,
        *,
        latitude: float,
        longitude: float,
        daily: tuple[str, ...] = DEFAULT_FLOOD_DAILY,
        forecast_days: int = 7,
        past_days: int = 0,
    ) -> WeatherResult:
        """River discharge (m3/s) from the GloFAS-based flood API. Returns the
        nearest river-grid cell, which can be far from an inland field."""
        if not 1 <= forecast_days <= 210:
            raise IntegrationValidationError("forecast_days must be 1-210", provider=PROVIDER)
        return await self._fetch(
            self._flood_url,
            dataset="Open-Meteo Flood",
            latitude=latitude,
            longitude=longitude,
            daily=daily,
            hourly=(),
            timezone=None,
            extra={"forecast_days": forecast_days, "past_days": past_days},
        )

    async def _fetch(
        self,
        url: str,
        *,
        dataset: str,
        latitude: float,
        longitude: float,
        daily: tuple[str, ...],
        hourly: tuple[str, ...],
        timezone: str | None,
        extra: dict[str, Any],
    ) -> WeatherResult:
        validate_lat_lon(latitude, longitude, provider=PROVIDER)
        if not daily and not hourly:
            raise IntegrationValidationError("request at least one variable", provider=PROVIDER)
        for name in (*daily, *hourly):
            if not _VAR_RE.match(name):
                raise IntegrationValidationError(
                    f"invalid variable name {name!r}", provider=PROVIDER
                )

        params: dict[str, Any] = {"latitude": latitude, "longitude": longitude, **extra}
        if daily:
            params["daily"] = ",".join(daily)
        if hourly:
            params["hourly"] = ",".join(hourly)
        if timezone:
            params["timezone"] = timezone
        if self._api_key:
            params["apikey"] = self._api_key

        # Open-Meteo explains 400s in {"reason": ...}; ProviderHttp already
        # puts the response body in the raised IntegrationRequestError.
        result = await self._http.get(url, dataset=dataset, params=params)
        payload = result.json()
        if not isinstance(payload, dict) or payload.get("error"):
            raise IntegrationResponseError(
                f"Open-Meteo error: {payload.get('reason') if isinstance(payload, dict) else payload}",
                provider=PROVIDER,
            )

        rows: list[WeatherRow] = []
        units: dict[str, str] = {}
        for block, parse_time in (("daily", _parse_day), ("hourly", _parse_hour)):
            body = payload.get(block)
            if not body:
                continue
            units.update(
                {k: v for k, v in payload.get(f"{block}_units", {}).items() if k != "time"}
            )
            rows.extend(_rows(body, parse_time, block))

        try:
            grid_lat = float(payload["latitude"])
            grid_lon = float(payload["longitude"])
        except (KeyError, TypeError, ValueError) as exc:
            raise IntegrationResponseError(
                f"Open-Meteo response missing coordinates: {exc}", provider=PROVIDER
            ) from exc
        return WeatherResult(
            rows=rows,
            units=units,
            requested_latitude=latitude,
            requested_longitude=longitude,
            grid_latitude=grid_lat,
            grid_longitude=grid_lon,
            elevation_m=payload.get("elevation"),
            timezone=payload.get("timezone"),
            provenance=result.provenance,
            raw=payload,
        )


def _parse_day(value: str) -> date:
    return date.fromisoformat(value)


def _parse_hour(value: str) -> datetime:
    return datetime.fromisoformat(value)


def _rows(body: dict[str, Any], parse_time: Any, block: str) -> list[WeatherRow]:
    times = body.get("time")
    if not isinstance(times, list):
        raise IntegrationResponseError(f"{block} block has no time array", provider=PROVIDER)
    variables = {k: v for k, v in body.items() if k != "time"}
    for name, series in variables.items():
        if not isinstance(series, list) or len(series) != len(times):
            raise IntegrationResponseError(
                f"{block}.{name} length does not match time array", provider=PROVIDER
            )
    return [
        WeatherRow(
            time=parse_time(stamp),
            values={name: (None if series[i] is None else float(series[i])) for name, series in variables.items()},
        )
        for i, stamp in enumerate(times)
    ]
