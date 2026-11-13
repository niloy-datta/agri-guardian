"""ISRIC WoSIS GraphQL: observed soil profiles.

Verified live: `POST https://graphql.isric.org/wosis/graphql` exposes
`wosisLatestProfiles`, `wosisLatestSites`, `wosisLatestLayers` and
`wosisLatestObservations`, each taking `first`, `offset`, `orderBy`,
`condition` and a PostGraphile-style `filter`. A bbox filter with
`latitude`/`longitude` `{greaterThanOrEqualTo, lessThanOrEqualTo}` returned
real Bangladeshi profiles (`BD0002`, `BD0009`, ...), and
`condition:{countryName:"Bangladesh"}` returned the BD-CHT-SOTER set.

Many legacy profiles have no sampling year (`year: null`); that is kept as
`None`. WoSIS is point observations, not a gridded map - use it to
sanity-check SoilGrids, not to replace it.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from app.integrations.common.errors import IntegrationResponseError, IntegrationValidationError
from app.integrations.common.geo import validate_bbox
from app.integrations.common.http import Provenance, ProviderHttp

PROVIDER = "ISRIC WoSIS"

_PROFILE_QUERY = """
query Profiles($first: Int!, $offset: Int!, $filter: WosisLatestProfileFilter) {
  wosisLatestProfiles(first: $first, offset: $offset, filter: $filter) {
    profileId profileCode datasetCode year latitude longitude countryName
    wrbReferenceSoilGroup
  }
}
"""


@dataclass(frozen=True, slots=True)
class WosisProfile:
    profile_id: int
    profile_code: str | None
    dataset_code: str | None
    year: int | None
    latitude: float | None
    longitude: float | None
    country: str | None
    wrb_soil_group: str | None


@dataclass(frozen=True, slots=True)
class WosisProfilesResult:
    profiles: list[WosisProfile]
    provenance: Provenance
    raw: dict[str, Any] = field(repr=False)


class WosisClient:
    def __init__(self, *, graphql_url: str, http: ProviderHttp) -> None:
        self._url = graphql_url
        self._http = http

    async def search_profiles_in_bbox(
        self,
        *,
        bbox: tuple[float, float, float, float],
        first: int = 50,
        offset: int = 0,
    ) -> WosisProfilesResult:
        west, south, east, north = validate_bbox(*bbox, provider=PROVIDER)
        if not 1 <= first <= 1000 or offset < 0:
            raise IntegrationValidationError("first must be 1-1000, offset >= 0", provider=PROVIDER)
        variables = {
            "first": first,
            "offset": offset,
            "filter": {
                "latitude": {"greaterThanOrEqualTo": south, "lessThanOrEqualTo": north},
                "longitude": {"greaterThanOrEqualTo": west, "lessThanOrEqualTo": east},
            },
        }
        result = await self._http.post(
            self._url,
            dataset="WoSIS profiles",
            json_body={"query": _PROFILE_QUERY, "variables": variables},
        )
        payload = result.json()
        if isinstance(payload, dict) and payload.get("errors"):
            raise IntegrationResponseError(
                f"WoSIS GraphQL errors: {payload['errors']}", provider=PROVIDER
            )
        try:
            rows = payload["data"]["wosisLatestProfiles"]
        except (KeyError, TypeError) as exc:
            raise IntegrationResponseError(
                f"WoSIS response missing data: {exc}", provider=PROVIDER
            ) from exc
        profiles = [
            WosisProfile(
                profile_id=int(r["profileId"]),
                profile_code=r.get("profileCode"),
                dataset_code=r.get("datasetCode"),
                year=r.get("year"),
                latitude=r.get("latitude"),
                longitude=r.get("longitude"),
                country=r.get("countryName"),
                wrb_soil_group=r.get("wrbReferenceSoilGroup"),
            )
            for r in rows
        ]
        return WosisProfilesResult(profiles=profiles, provenance=result.provenance, raw=payload)
