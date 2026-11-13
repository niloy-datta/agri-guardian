"""FAOSTAT: crop area, yield and production statistics.

**Verified live: FAOSTAT's query API now requires authentication.**
`GET /api/v1/en/data/QCL?...` and `/definitions/*` return HTTP 401
`Missing Authorization Header`, and `POST /auth/login` needs a confirmed
FAOSTAT account (a bogus login returned "User is not confirmed"). So this
module has two paths:

1. **Bulk files (keyless, verified).** `https://bulks-faostat.fao.org/
   production/datasets_E.json` lists every dataset with its zip
   (`FileLocation`, `FileRows`, `DateUpdate`). For QCL (Production: Crops
   and livestock products) the normalized zip is ~34 MB and its CSV is
   UTF-8 with columns `Area Code, Area Code (M49), Area, Item Code, Item
   Code (CPC), Item, Element Code, Element, Year Code, Year, Unit, Value,
   Flag, Note`. For Bangladesh / Rice / 2022 it contained Area harvested
   (ha), Yield (kg/ha) and Production (t), all flagged `A` (official).
   `fetch_bulk_rows` downloads the zip (optionally cached on disk) and
   filters it; M49/CPC codes carry a leading apostrophe in the file and
   are returned stripped.
2. **Query API (needs `faostat_token`).** `query_data` calls the
   authenticated endpoint. Its response shape was not observable without a
   token, so it returns the decoded JSON untouched.

Values are kept as `None` when empty - never 0 - and the FAOSTAT `Flag`
is preserved because `E`/`I`/`M` mean estimated/imputed/missing.
"""

from __future__ import annotations

import csv
import io
import time
import zipfile
from collections.abc import Iterable
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from app.integrations.common.errors import (
    IntegrationCredentialsMissingError,
    IntegrationResponseError,
    IntegrationValidationError,
)
from app.integrations.common.http import Provenance, ProviderHttp

PROVIDER = "FAOSTAT"
_CACHE_MAX_AGE_SECONDS = 7 * 24 * 3600


@dataclass(frozen=True, slots=True)
class FaoBulkDataset:
    code: str
    name: str
    file_location: str | None
    file_rows: int | None
    file_size: str | None
    date_updated: str | None


@dataclass(frozen=True, slots=True)
class FaoObservation:
    area: str
    area_code_m49: str
    item: str
    item_code_cpc: str
    element: str
    element_code: str
    year: int
    unit: str
    value: float | None
    flag: str | None


@dataclass(frozen=True, slots=True)
class FaoBulkResult:
    observations: list[FaoObservation]
    provenance: Provenance


class FaostatClient:
    def __init__(
        self,
        *,
        api_url: str,
        bulk_catalog_url: str,
        token: str,
        http: ProviderHttp,
        cache_dir: Path | None = None,
    ) -> None:
        self._api = api_url.rstrip("/")
        self._catalog_url = bulk_catalog_url
        self._token = token
        self._http = http
        self._cache_dir = cache_dir

    async def list_bulk_datasets(self) -> list[FaoBulkDataset]:
        result = await self._http.get(self._catalog_url, dataset="FAOSTAT bulk catalog")
        payload = result.json()
        try:
            rows = payload["Datasets"]["Dataset"]
        except (KeyError, TypeError) as exc:
            raise IntegrationResponseError(
                f"bulk catalog malformed: {exc}", provider=PROVIDER
            ) from exc
        return [
            FaoBulkDataset(
                code=str(r["DatasetCode"]),
                name=str(r.get("DatasetName", "")),
                file_location=r.get("FileLocation"),
                file_rows=r.get("FileRows"),
                file_size=r.get("FileSize"),
                date_updated=r.get("DateUpdate"),
            )
            for r in rows
        ]

    async def fetch_bulk_rows(
        self,
        *,
        dataset_code: str,
        areas: tuple[str, ...],
        items: tuple[str, ...] = (),
        elements: tuple[str, ...] = (),
        year_from: int | None = None,
        year_to: int | None = None,
    ) -> FaoBulkResult:
        """Filters a bulk dataset by exact area / item / element names, e.g.
        `areas=("Bangladesh",), items=("Rice",), elements=("Yield",)`."""
        if not areas:
            raise IntegrationValidationError("provide at least one area", provider=PROVIDER)
        datasets = await self.list_bulk_datasets()
        dataset = next((d for d in datasets if d.code == dataset_code), None)
        if dataset is None or not dataset.file_location:
            raise IntegrationValidationError(
                f"unknown FAOSTAT dataset {dataset_code!r}", provider=PROVIDER
            )
        content, provenance = await self._download_zip(dataset)
        rows = _filter_normalized_csv(
            content,
            areas=set(areas),
            items=set(items),
            elements=set(elements),
            year_from=year_from,
            year_to=year_to,
        )
        return FaoBulkResult(observations=rows, provenance=provenance)

    async def query_data(self, domain: str, **filters: str) -> Any:
        """Authenticated query API (needs `faostat_token`). Returns the raw
        decoded JSON - its shape could not be observed without a token."""
        if not self._token:
            raise IntegrationCredentialsMissingError(
                "FAOSTAT query API needs faostat_token; use fetch_bulk_rows for the keyless path",
                provider=PROVIDER,
            )
        result = await self._http.get(
            f"{self._api}/en/data/{domain}",
            dataset=f"FAOSTAT {domain}",
            params={"output_type": "objects", "show_codes": "true", **filters},
            bearer=self._token,
        )
        return result.json()

    async def _download_zip(self, dataset: FaoBulkDataset) -> tuple[bytes, Provenance]:
        assert dataset.file_location
        cache_file = (
            self._cache_dir / f"faostat_{dataset.code}.zip" if self._cache_dir else None
        )
        if cache_file and cache_file.exists():
            age = time.time() - cache_file.stat().st_mtime
            if age < _CACHE_MAX_AGE_SECONDS:
                from datetime import UTC, datetime

                return cache_file.read_bytes(), Provenance(
                    provider=PROVIDER,
                    dataset=f"FAOSTAT {dataset.code} bulk",
                    source_url=dataset.file_location,
                    retrieved_at=datetime.fromtimestamp(cache_file.stat().st_mtime, UTC),
                    data_mode="cache",
                )
        result = await self._http.get(dataset.file_location, dataset=f"FAOSTAT {dataset.code} bulk")
        if cache_file:
            cache_file.parent.mkdir(parents=True, exist_ok=True)
            cache_file.write_bytes(result.content)
        return result.content, result.provenance


def _strip_code(value: str) -> str:
    return value[1:] if value.startswith("'") else value


def _filter_normalized_csv(
    content: bytes,
    *,
    areas: set[str],
    items: set[str],
    elements: set[str],
    year_from: int | None,
    year_to: int | None,
) -> list[FaoObservation]:
    try:
        archive = zipfile.ZipFile(io.BytesIO(content))
    except zipfile.BadZipFile as exc:
        raise IntegrationResponseError(
            "FAOSTAT bulk file is not a zip", provider=PROVIDER
        ) from exc
    names = [n for n in archive.namelist() if n.endswith("Normalized).csv")]
    if not names:
        raise IntegrationResponseError(
            "no normalized CSV in FAOSTAT zip", provider=PROVIDER
        )
    observations: list[FaoObservation] = []
    with archive.open(names[0]) as raw:
        reader = csv.DictReader(io.TextIOWrapper(raw, encoding="utf-8"))
        for row in reader:
            if row["Area"] not in areas:
                continue
            if items and row["Item"] not in items:
                continue
            if elements and row["Element"] not in elements:
                continue
            year = int(row["Year"])
            if (year_from is not None and year < year_from) or (
                year_to is not None and year > year_to
            ):
                continue
            raw_value = row["Value"].strip()
            observations.append(
                FaoObservation(
                    area=row["Area"],
                    area_code_m49=_strip_code(row["Area Code (M49)"]),
                    item=row["Item"],
                    item_code_cpc=_strip_code(row["Item Code (CPC)"]),
                    element=row["Element"],
                    element_code=row["Element Code"],
                    year=year,
                    unit=row["Unit"],
                    value=float(raw_value) if raw_value else None,
                    flag=row["Flag"] or None,
                )
            )
    return observations


def latest_by_element(observations: Iterable[FaoObservation]) -> dict[str, FaoObservation]:
    """Most recent non-null observation per element, e.g. latest Yield."""
    best: dict[str, FaoObservation] = {}
    for obs in observations:
        if obs.value is None:
            continue
        current = best.get(obs.element)
        if current is None or obs.year > current.year:
            best[obs.element] = obs
    return best
