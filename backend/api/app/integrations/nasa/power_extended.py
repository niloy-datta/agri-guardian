"""NASA POWER Hourly, Monthly, Climatology and CMIP6 Projection clients.

Complements `client.py` (Daily Point, which stays the project's audited
path for the planting-window evidence chain). Request shapes and response
envelopes here were confirmed against live POWER responses:

- Hourly:  `/api/temporal/hourly/point` -> keys `YYYYMMDDHH`.
- Monthly: `/api/temporal/monthly/point` (start/end are *years*) -> keys
  `YYYYMM`, with `YYYY13` holding the annual mean (not a 13th month).
- Climatology: `/api/temporal/climatology/point` -> keys `JAN..DEC`,
  `ANN`; no date arguments.
- Projection: `/api/projection/daily/point` (NASA/CMIP6 NEX-GDDP) -> keys
  nested `scenario -> YYYYMMDD`; `model` must be one of the lowercase
  underscore names the API enumerates (the hyphenated form is a 422).

Every API echoes `header.fill_value` (-999); it is converted to `None`,
never to 0.

**Coverage warning (verified live):** the Projection API returned
`-999` for every day, scenario and model tried at points in Bangladesh and
northern India, while returning real values for a US point. The client
reports that honestly via `PowerProjectionResult.has_coverage == False`
instead of pretending the future is zero. Do not build advisories on this
endpoint for Bangladesh until NASA fills it.
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

PROVIDER = "NASA POWER"
_PARAM_RE = re.compile(r"^[A-Z0-9_]+$")
_MAX_PARAMETERS = 20
COMMUNITIES = frozenset({"AG", "RE", "SB"})
MONTH_KEYS = ("JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC")

# Verified against the live API's own 422 enumeration.
PROJECTION_MODELS = frozenset(
    {
        "ensemble", "access_cm2", "access_esm1_5", "bcc_csm2_mr", "cesm2", "cmcc_esm2",
        "cnrm_cm6_1", "cnrm_esm2_1", "ec_earth3", "fgoals_g3", "gfdl_esm4", "giss_e2_1_g",
        "inm_cm4_8", "inm_cm5_0", "ipsl_cm6a_lr", "kace_1_0_g", "miroc6", "miroc_es2l",
        "mpi_esm1_2_hr", "mpi_esm1_2_lr", "mri_esm2_0", "noresm2_lm", "noresm2_mm",
    }
)  # fmt: skip
PROJECTION_SCENARIOS = frozenset({"ssp126", "ssp245", "ssp370"})


@dataclass(frozen=True, slots=True)
class PowerSeries:
    parameter: str
    units: str | None
    values: dict[str, float | None]
    """Keyed by the provider's own period key (see module docstring)."""


@dataclass(frozen=True, slots=True)
class PowerResult:
    series: dict[str, PowerSeries]
    provenance: Provenance
    fill_value: float | None
    header: dict[str, Any]
    raw: dict[str, Any] = field(repr=False)


@dataclass(frozen=True, slots=True)
class PowerHourlyPoint:
    timestamp: datetime
    values: dict[str, float | None]


@dataclass(frozen=True, slots=True)
class PowerMonthlyResult:
    """Monthly means (`monthly[(year, month)][parameter]`) with the annual
    mean (`annual[year][parameter]`) separated from the monthly keys."""

    monthly: dict[tuple[int, int], dict[str, float | None]]
    annual: dict[int, dict[str, float | None]]
    units: dict[str, str]
    provenance: Provenance
    raw: dict[str, Any] = field(repr=False)


@dataclass(frozen=True, slots=True)
class PowerClimatologyResult:
    """`monthly[param][1..12]` plus `annual[param]` from the 25-year baseline."""

    monthly: dict[str, dict[int, float | None]]
    annual: dict[str, float | None]
    units: dict[str, str]
    period: str | None
    provenance: Provenance
    raw: dict[str, Any] = field(repr=False)


@dataclass(frozen=True, slots=True)
class PowerProjectionResult:
    """`values[scenario][parameter][date]`. `has_coverage` is False when the
    provider returned only fill values (see module docstring)."""

    values: dict[str, dict[str, dict[date, float | None]]]
    units: dict[str, str]
    model: str
    has_coverage: bool
    provenance: Provenance
    raw: dict[str, Any] = field(repr=False)


class NasaPowerExtendedClient:
    def __init__(self, *, base_url: str, http: ProviderHttp) -> None:
        self._base = base_url.rstrip("/")
        self._http = http

    # -- public API ------------------------------------------------------

    async def fetch_hourly(
        self,
        *,
        latitude: float,
        longitude: float,
        start: date,
        end: date,
        parameters: tuple[str, ...],
        community: str = "AG",
        time_standard: str = "LST",
    ) -> list[PowerHourlyPoint]:
        self._validate(latitude, longitude, parameters, community)
        validate_date_range(start, end, provider=PROVIDER)
        if time_standard not in ("LST", "UTC"):
            raise IntegrationValidationError("time_standard must be LST or UTC", provider=PROVIDER)
        result = await self._get(
            "hourly",
            dataset="POWER Hourly",
            latitude=latitude,
            longitude=longitude,
            parameters=parameters,
            community=community,
            extra={
                "start": start.strftime("%Y%m%d"),
                "end": end.strftime("%Y%m%d"),
                "time-standard": time_standard,
            },
        )
        by_time: dict[datetime, dict[str, float | None]] = {}
        for name, series in result.series.items():
            for key, value in series.values.items():
                try:
                    stamp = datetime.strptime(key, "%Y%m%d%H")
                except ValueError as exc:
                    raise IntegrationResponseError(
                        f"unexpected hourly key {key!r}", provider=PROVIDER
                    ) from exc
                by_time.setdefault(stamp, {})[name] = value
        return [PowerHourlyPoint(t, v) for t, v in sorted(by_time.items())]

    async def fetch_monthly(
        self,
        *,
        latitude: float,
        longitude: float,
        start_year: int,
        end_year: int,
        parameters: tuple[str, ...],
        community: str = "AG",
    ) -> PowerMonthlyResult:
        self._validate(latitude, longitude, parameters, community)
        if start_year > end_year:
            raise IntegrationValidationError("start_year must be <= end_year", provider=PROVIDER)
        result = await self._get(
            "monthly",
            dataset="POWER Monthly and Annual",
            latitude=latitude,
            longitude=longitude,
            parameters=parameters,
            community=community,
            extra={"start": str(start_year), "end": str(end_year)},
        )
        monthly: dict[tuple[int, int], dict[str, float | None]] = {}
        annual: dict[int, dict[str, float | None]] = {}
        for name, series in result.series.items():
            for key, value in series.values.items():
                if len(key) != 6 or not key.isdigit():
                    raise IntegrationResponseError(
                        f"unexpected monthly key {key!r}", provider=PROVIDER
                    )
                year, month = int(key[:4]), int(key[4:])
                if month == 13:
                    annual.setdefault(year, {})[name] = value
                elif 1 <= month <= 12:
                    monthly.setdefault((year, month), {})[name] = value
                else:
                    raise IntegrationResponseError(
                        f"unexpected monthly key {key!r}", provider=PROVIDER
                    )
        return PowerMonthlyResult(
            monthly=monthly,
            annual=annual,
            units=_units(result),
            provenance=result.provenance,
            raw=result.raw,
        )

    async def fetch_climatology(
        self,
        *,
        latitude: float,
        longitude: float,
        parameters: tuple[str, ...],
        community: str = "AG",
    ) -> PowerClimatologyResult:
        self._validate(latitude, longitude, parameters, community)
        result = await self._get(
            "climatology",
            dataset="POWER Climatology",
            latitude=latitude,
            longitude=longitude,
            parameters=parameters,
            community=community,
            extra={},
        )
        monthly: dict[str, dict[int, float | None]] = {}
        annual: dict[str, float | None] = {}
        for name, series in result.series.items():
            monthly[name] = {}
            for key, value in series.values.items():
                if key == "ANN":
                    annual[name] = value
                elif key in MONTH_KEYS:
                    monthly[name][MONTH_KEYS.index(key) + 1] = value
                else:
                    raise IntegrationResponseError(
                        f"unexpected climatology key {key!r}", provider=PROVIDER
                    )
        return PowerClimatologyResult(
            monthly=monthly,
            annual=annual,
            units=_units(result),
            period=result.header.get("range"),
            provenance=result.provenance,
            raw=result.raw,
        )

    async def fetch_projection(
        self,
        *,
        latitude: float,
        longitude: float,
        start: date,
        end: date,
        parameters: tuple[str, ...],
        community: str = "AG",
        model: str = "ensemble",
        scenario: str | None = None,
    ) -> PowerProjectionResult:
        self._validate(latitude, longitude, parameters, community)
        validate_date_range(start, end, provider=PROVIDER)
        if model not in PROJECTION_MODELS:
            raise IntegrationValidationError(
                f"unknown CMIP6 model {model!r}; use lowercase underscore names", provider=PROVIDER
            )
        if scenario is not None and scenario not in PROJECTION_SCENARIOS:
            raise IntegrationValidationError(
                f"scenario must be one of {sorted(PROJECTION_SCENARIOS)}", provider=PROVIDER
            )
        extra: dict[str, str] = {
            "start": start.strftime("%Y%m%d"),
            "end": end.strftime("%Y%m%d"),
            "model": model,
        }
        if scenario:
            extra["scenario"] = scenario
        path = "/api/projection/daily/point"
        http_result = await self._http.get(
            f"{self._base}{path}",
            dataset="POWER CMIP6 NEX-GDDP",
            params=self._query(latitude, longitude, parameters, community, extra),
        )
        payload = http_result.json()
        header, units, fill = _envelope(payload)
        try:
            raw_params: dict[str, dict[str, dict[str, Any]]] = payload["properties"]["parameter"]
        except (KeyError, TypeError) as exc:
            raise IntegrationResponseError(
                f"projection response missing field: {exc}", provider=PROVIDER
            ) from exc

        values: dict[str, dict[str, dict[date, float | None]]] = {}
        any_value = False
        for parameter, per_scenario in raw_params.items():
            for scenario_name, days in per_scenario.items():
                bucket = values.setdefault(scenario_name, {}).setdefault(parameter, {})
                for key, raw_value in days.items():
                    value = _clean(raw_value, fill)
                    any_value = any_value or value is not None
                    bucket[datetime.strptime(key, "%Y%m%d").date()] = value
        return PowerProjectionResult(
            values=values,
            units=units,
            model=str(header.get("model", model)),
            has_coverage=any_value,
            provenance=http_result.provenance,
            raw=payload,
        )

    # -- internals -------------------------------------------------------

    def _query(
        self,
        latitude: float,
        longitude: float,
        parameters: tuple[str, ...],
        community: str,
        extra: dict[str, str],
    ) -> dict[str, Any]:
        return {
            "parameters": ",".join(parameters),
            "community": community,
            "latitude": latitude,
            "longitude": longitude,
            "format": "JSON",
            **extra,
        }

    async def _get(
        self,
        temporal: str,
        *,
        dataset: str,
        latitude: float,
        longitude: float,
        parameters: tuple[str, ...],
        community: str,
        extra: dict[str, str],
    ) -> PowerResult:
        http_result = await self._http.get(
            f"{self._base}/api/temporal/{temporal}/point",
            dataset=dataset,
            params=self._query(latitude, longitude, parameters, community, extra),
        )
        payload = http_result.json()
        header, units, fill = _envelope(payload)
        try:
            raw_series: dict[str, dict[str, Any]] = payload["properties"]["parameter"]
        except (KeyError, TypeError) as exc:
            raise IntegrationResponseError(
                f"POWER {temporal} response missing field: {exc}", provider=PROVIDER
            ) from exc
        series = {
            name: PowerSeries(
                parameter=name,
                units=units.get(name),
                values={k: _clean(v, fill) for k, v in values.items()},
            )
            for name, values in raw_series.items()
        }
        return PowerResult(
            series=series,
            provenance=http_result.provenance,
            fill_value=fill,
            header=header,
            raw=payload,
        )

    @staticmethod
    def _validate(
        latitude: float, longitude: float, parameters: tuple[str, ...], community: str
    ) -> None:
        validate_lat_lon(latitude, longitude, provider=PROVIDER)
        if not parameters or len(parameters) > _MAX_PARAMETERS:
            raise IntegrationValidationError(
                f"provide 1-{_MAX_PARAMETERS} parameters", provider=PROVIDER
            )
        for name in parameters:
            if not _PARAM_RE.match(name):
                raise IntegrationValidationError(
                    f"invalid parameter name {name!r}", provider=PROVIDER
                )
        if community not in COMMUNITIES:
            raise IntegrationValidationError(
                f"community must be one of {sorted(COMMUNITIES)}", provider=PROVIDER
            )


def _envelope(payload: Any) -> tuple[dict[str, Any], dict[str, str], float | None]:
    try:
        header: dict[str, Any] = payload["header"]
        meta: dict[str, Any] = payload["parameters"]
    except (KeyError, TypeError) as exc:
        raise IntegrationResponseError(
            f"POWER response missing field: {exc}", provider=PROVIDER
        ) from exc
    fill = header.get("fill_value")
    units = {k: m["units"] for k, m in meta.items() if isinstance(m, dict) and "units" in m}
    return header, units, float(fill) if fill is not None else None


def _units(result: PowerResult) -> dict[str, str]:
    return {k: s.units for k, s in result.series.items() if s.units}


def _clean(raw: Any, fill: float | None) -> float | None:
    if raw is None:
        return None
    try:
        value = float(raw)
    except (TypeError, ValueError):
        return None
    if fill is not None and value == fill:
        return None
    return value
