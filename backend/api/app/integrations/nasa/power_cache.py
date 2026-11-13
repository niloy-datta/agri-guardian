"""Filesystem acquisition cache for NASA POWER evidence.

Not Redis, not `platform.outbox_events` - this is a cache over an
*external data acquisition*, not application business state, so it is a
directory of JSON files keyed by the exact request that produced them.

Cache policy:
1. Look for a matching local cache entry; if present, use it.
2. Otherwise, if `NASA_POWER_OFFLINE=true`, look for a matching committed
   demo/test fixture; if present, verify it against its manifest entry
   (Task 4 integrity check below) and use it.
3. Otherwise, if offline, fail clearly - never invent evidence.
4. Otherwise (online, no cache hit), fetch from NASA POWER, validate,
   persist the raw response (plus a small provenance sidecar), and
   return it.

`force_refresh=True` bypasses step 1 for an explicit refresh; it never
bypasses offline mode, which makes zero network calls under any
circumstance.

Provenance across a cache or fixture replay: `source_url` and
`retrieved_at` always describe the *original* NASA request, never a
`file://` path or "now" - see `NasaPowerProvenance` in `client.py`. A
cache hit restores this from a small `<key>.meta.json` sidecar written
alongside the raw response at acquisition time; a fixture hit restores it
from the fixture's own `manifest.json` entry, which is also where the
integrity check below reads its checksum from.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path
from typing import Any

from app.integrations.nasa.client import (
    DEFAULT_PARAMETERS,
    NasaPowerClient,
    PowerDailyResponse,
)

MANIFEST_FILENAME = "manifest.json"

REQUIRED_MANIFEST_ENTRY_FIELDS = (
    "file",
    "provider",
    "dataset_id",
    "source_url",
    "endpoint",
    "request",
    "units",
    "retrieved_at",
    "sha256",
    "synthetic",
)


class NasaPowerUnavailableOfflineError(Exception):
    """Raised in offline mode when neither the cache nor a committed
    fixture has a matching entry. Never caught silently - there is no
    fallback data to invent."""


class NasaEvidenceIntegrityError(Exception):
    """Raised when a committed demo fixture fails manifest verification:
    missing manifest, missing/incomplete entry, an entry claiming
    `synthetic: true`, or a checksum that does not match the file's
    actual bytes. The fixture is never parsed or returned when this is
    raised - there is no fallback to unverified or fabricated evidence."""


@dataclass(frozen=True, slots=True)
class CacheLookupResult:
    """What actually happened, for the advisory service's `warnings` list
    and for tests - not just the response."""

    response: PowerDailyResponse
    source: str
    """'cache', 'fixture', or 'live', matching
    `NasaPowerProvenance.data_mode`."""


def canonical_cache_key(
    *,
    latitude: float,
    longitude: float,
    start: date,
    end: date,
    parameters: tuple[str, ...],
    community: str,
    time_standard: str = "LST",
) -> str:
    """A deterministic key covering every input that changes the NASA
    POWER response: two requests differing in any of these fields must
    never collide.

    Coordinates are rounded to 6 decimal places (~0.11 m) before hashing
    so floating-point representation noise (e.g. `23.8500000001` vs
    `23.85`) does not silently create a second cache entry for what is
    the same request.
    """
    canonical = {
        "latitude": round(latitude, 6),
        "longitude": round(longitude, 6),
        "start": start.isoformat(),
        "end": end.isoformat(),
        "parameters": sorted(parameters),
        "community": community,
        "time_standard": time_standard,
    }
    encoded = json.dumps(canonical, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def load_manifest(fixture_dir: Path) -> dict[str, Any] | None:
    """Returns the parsed manifest, or None if absent/corrupted. A
    corrupted manifest is treated as absent, never as valid."""
    manifest_path = fixture_dir / MANIFEST_FILENAME
    if not manifest_path.exists():
        return None
    try:
        return json.loads(manifest_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None


def verify_fixture_entry(fixture_dir: Path, filename: str) -> dict[str, Any]:
    """The single, canonical fixture-integrity check, used both by the
    runtime offline path below and by
    `scripts/fetch_power_fixture.py --verify-manifest` - one algorithm,
    not two. Returns the verified manifest entry, or raises
    `NasaEvidenceIntegrityError` with a clear reason.
    """
    manifest = load_manifest(fixture_dir)
    if manifest is None:
        raise NasaEvidenceIntegrityError(f"No {MANIFEST_FILENAME} found in {fixture_dir}")
    if manifest.get("synthetic") is not False:
        raise NasaEvidenceIntegrityError(
            f"{MANIFEST_FILENAME} must declare synthetic: false for real NASA demo evidence"
        )

    entry = next((e for e in manifest.get("files", []) if e.get("file") == filename), None)
    if entry is None:
        raise NasaEvidenceIntegrityError(f"No manifest entry for fixture file '{filename}'")

    missing = [f for f in REQUIRED_MANIFEST_ENTRY_FIELDS if f not in entry]
    if missing:
        raise NasaEvidenceIntegrityError(
            f"Manifest entry for '{filename}' missing required fields: {missing}"
        )
    if entry["synthetic"] is not False:
        raise NasaEvidenceIntegrityError(f"Manifest entry for '{filename}' claims synthetic=true")

    fixture_path = fixture_dir / filename
    if not fixture_path.exists():
        raise NasaEvidenceIntegrityError(f"Fixture file not found: {fixture_path}")

    actual_checksum = hashlib.sha256(fixture_path.read_bytes()).hexdigest()
    if actual_checksum != entry["sha256"]:
        raise NasaEvidenceIntegrityError(
            f"Checksum mismatch for '{filename}': manifest={entry['sha256']}, "
            f"actual={actual_checksum} - evidence may have been modified. Rejected."
        )
    return entry


class NasaPowerCache:
    def __init__(
        self,
        *,
        client: NasaPowerClient,
        cache_dir: Path,
        fixture_dir: Path,
        offline: bool,
    ) -> None:
        self._client = client
        self._cache_dir = cache_dir
        self._fixture_dir = fixture_dir
        self._offline = offline

    def _cache_path(self, key: str) -> Path:
        return self._cache_dir / f"{key}.json"

    def _cache_meta_path(self, key: str) -> Path:
        return self._cache_dir / f"{key}.meta.json"

    def _fixture_path(self, key: str) -> Path:
        return self._fixture_dir / f"{key}.json"

    @staticmethod
    def _load_raw(path: Path) -> dict[str, Any] | None:
        """Returns the parsed body, or None if the file does not exist or
        cannot be parsed. A corrupted file is treated as absent - it is
        never returned as if it were valid evidence."""
        if not path.exists():
            return None
        try:
            with path.open(encoding="utf-8") as handle:
                return json.load(handle)
        except (json.JSONDecodeError, OSError):
            return None

    def _save_raw(self, path: Path, raw: dict[str, Any]) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp_path = path.with_suffix(".json.tmp")
        with tmp_path.open("w", encoding="utf-8") as handle:
            json.dump(raw, handle, sort_keys=True, indent=2)
        tmp_path.replace(path)

    async def get_daily_point(
        self,
        *,
        latitude: float,
        longitude: float,
        start: date,
        end: date,
        parameters: tuple[str, ...] | None = None,
        community: str = "AG",
        force_refresh: bool = False,
    ) -> CacheLookupResult:
        resolved_parameters = parameters or DEFAULT_PARAMETERS
        key = canonical_cache_key(
            latitude=latitude,
            longitude=longitude,
            start=start,
            end=end,
            parameters=resolved_parameters,
            community=community,
        )

        def _parse(
            raw: dict[str, Any],
            *,
            source_url: str,
            data_mode: str,
            retrieved_at: datetime | None = None,
            local_evidence_path: str | None = None,
            fixture_sha256: str | None = None,
        ) -> PowerDailyResponse:
            return self._client.parse_daily_point_response(
                raw,
                parameters=resolved_parameters,
                community=community,
                latitude=latitude,
                longitude=longitude,
                start=start,
                end=end,
                source_url=source_url,
                data_mode=data_mode,
                retrieved_at=retrieved_at,
                local_evidence_path=local_evidence_path,
                fixture_sha256=fixture_sha256,
            )

        if not force_refresh:
            cache_path = self._cache_path(key)
            cached_raw = self._load_raw(cache_path)
            if cached_raw is not None:
                meta = self._load_raw(self._cache_meta_path(key)) or {}
                original_source_url = meta.get("source_url")
                original_retrieved_at = (
                    datetime.fromisoformat(meta["retrieved_at"])
                    if "retrieved_at" in meta
                    else None
                )
                response = _parse(
                    cached_raw,
                    # Falls back to the local path only if an older cache
                    # entry has no provenance sidecar yet.
                    source_url=original_source_url or f"file://{cache_path}",
                    data_mode="cache",
                    retrieved_at=original_retrieved_at,
                    local_evidence_path=str(cache_path),
                )
                return CacheLookupResult(response=response, source="cache")

        if self._offline:
            fixture_path = self._fixture_path(key)
            if fixture_path.exists():
                # Raises NasaEvidenceIntegrityError on any problem; a
                # tampered or unmanifested fixture is never parsed.
                entry = verify_fixture_entry(self._fixture_dir, fixture_path.name)
                fixture_raw = self._load_raw(fixture_path)
                if fixture_raw is not None:
                    response = _parse(
                        fixture_raw,
                        source_url=entry["source_url"],
                        data_mode="fixture",
                        retrieved_at=datetime.fromisoformat(entry["retrieved_at"]),
                        local_evidence_path=str(fixture_path),
                        fixture_sha256=entry["sha256"],
                    )
                    return CacheLookupResult(response=response, source="fixture")

            raise NasaPowerUnavailableOfflineError(
                "NASA evidence unavailable offline: no cache entry or committed "
                f"fixture for latitude={latitude}, longitude={longitude}, "
                f"{start.isoformat()}..{end.isoformat()}, "
                f"parameters={resolved_parameters}, community={community} "
                f"(cache key {key})."
            )

        response = await self._client.fetch_daily_point(
            latitude=latitude,
            longitude=longitude,
            start=start,
            end=end,
            parameters=resolved_parameters,
            community=community,
        )
        self._save_raw(self._cache_path(key), response.raw)
        self._save_raw(
            self._cache_meta_path(key),
            {
                "source_url": response.provenance.source_url,
                "retrieved_at": response.provenance.retrieved_at.isoformat(),
            },
        )
        return CacheLookupResult(response=response, source="live")
