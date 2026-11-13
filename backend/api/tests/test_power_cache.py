"""Unit tests for the NASA POWER filesystem cache.

All I/O happens under pytest's `tmp_path` - nothing here ever reads or
writes the repository's own `cache/` or `demo_fixtures/` directories.
Every fixture payload used is SYNTHETIC TEST DATA - NOT NASA OBSERVATIONS.
"""

import json
from datetime import date
from pathlib import Path

import httpx
import pytest

from app.integrations.nasa.client import NasaPowerClient
from app.integrations.nasa.power_cache import (
    NasaEvidenceIntegrityError,
    NasaPowerCache,
    NasaPowerUnavailableOfflineError,
    canonical_cache_key,
)
from scripts.fetch_power_fixture import verify_manifest

FILL_VALUE = -999.0


def _write_fixture_with_manifest(
    fixture_dir: Path, *, key: str, payload: dict, synthetic: bool = False
) -> None:
    """Writes `<key>.json` plus a matching, checksum-correct manifest.json
    entry - what `scripts/fetch_power_fixture.py` produces for a real
    acquisition. SYNTHETIC TEST DATA - NOT NASA OBSERVATIONS."""
    import hashlib

    fixture_dir.mkdir(parents=True, exist_ok=True)
    raw_bytes = json.dumps(payload).encode("utf-8")
    (fixture_dir / f"{key}.json").write_bytes(raw_bytes)
    manifest = {
        "provider": "NASA POWER",
        "synthetic": False,
        "files": [
            {
                "file": f"{key}.json",
                "provider": "NASA POWER",
                "dataset_id": "SYNTHETIC TEST DATA - NOT NASA OBSERVATIONS",
                "source_url": "https://power.larc.nasa.gov/api/temporal/daily/point?test=1",
                "endpoint": "/api/temporal/daily/point",
                "request": {"parameters": ["PRECTOTCORR", "T2M_MAX", "T2M_MIN"], "community": "AG"},
                "units": {"PRECTOTCORR": "mm/day", "T2M_MAX": "C", "T2M_MIN": "C"},
                "retrieved_at": "2020-06-01T00:00:00+00:00",
                "sha256": hashlib.sha256(raw_bytes).hexdigest(),
                "synthetic": synthetic,
            }
        ],
    }
    (fixture_dir / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")


def _payload(day: str = "20200101") -> dict:
    """SYNTHETIC TEST DATA - NOT NASA OBSERVATIONS."""
    return {
        "properties": {
            "parameter": {
                "PRECTOTCORR": {day: 5.0},
                "T2M_MAX": {day: 30.0},
                "T2M_MIN": {day: 20.0},
            }
        },
        "header": {
            "title": "NASA/POWER Source Native Resolution Daily Data",
            "fill_value": FILL_VALUE,
            "time_standard": "LST",
        },
        "parameters": {
            "PRECTOTCORR": {"units": "mm/day"},
            "T2M_MAX": {"units": "C"},
            "T2M_MIN": {"units": "C"},
        },
    }


class _CountingTransport(httpx.AsyncBaseTransport):
    """Counts requests and always serves the same synthetic payload, so a
    cache hit's absence of HTTP traffic is directly observable."""

    def __init__(self, payload: dict) -> None:
        self.request_count = 0
        self._payload = payload

    async def handle_async_request(self, request: httpx.Request) -> httpx.Response:
        self.request_count += 1
        return httpx.Response(200, json=self._payload)


def _cache(tmp_path: Path, *, offline: bool, transport: _CountingTransport) -> NasaPowerCache:
    http_client = httpx.AsyncClient(transport=transport)
    client = NasaPowerClient(
        base_url="https://power.larc.nasa.gov", timeout_seconds=5.0, http_client=http_client
    )
    return NasaPowerCache(
        client=client,
        cache_dir=tmp_path / "cache",
        fixture_dir=tmp_path / "fixtures",
        offline=offline,
    )


async def test_identical_request_gets_same_cache_key() -> None:
    key1 = canonical_cache_key(
        latitude=24.36,
        longitude=90.35,
        start=date(2020, 1, 1),
        end=date(2020, 1, 10),
        parameters=("PRECTOTCORR", "T2M_MAX", "T2M_MIN"),
        community="AG",
    )
    key2 = canonical_cache_key(
        latitude=24.36,
        longitude=90.35,
        start=date(2020, 1, 1),
        end=date(2020, 1, 10),
        parameters=("PRECTOTCORR", "T2M_MAX", "T2M_MIN"),
        community="AG",
    )
    assert key1 == key2


async def test_different_parameter_set_changes_cache_key() -> None:
    key1 = canonical_cache_key(
        latitude=24.36,
        longitude=90.35,
        start=date(2020, 1, 1),
        end=date(2020, 1, 10),
        parameters=("PRECTOTCORR",),
        community="AG",
    )
    key2 = canonical_cache_key(
        latitude=24.36,
        longitude=90.35,
        start=date(2020, 1, 1),
        end=date(2020, 1, 10),
        parameters=("PRECTOTCORR", "T2M_MAX"),
        community="AG",
    )
    assert key1 != key2


async def test_cache_hit_avoids_http(tmp_path: Path) -> None:
    transport = _CountingTransport(_payload())
    cache = _cache(tmp_path, offline=False, transport=transport)

    first = await cache.get_daily_point(
        latitude=24.36, longitude=90.35, start=date(2020, 1, 1), end=date(2020, 1, 1)
    )
    second = await cache.get_daily_point(
        latitude=24.36, longitude=90.35, start=date(2020, 1, 1), end=date(2020, 1, 1)
    )

    assert first.source == "live"
    assert second.source == "cache"
    assert transport.request_count == 1


async def test_successful_fetch_writes_cache(tmp_path: Path) -> None:
    transport = _CountingTransport(_payload())
    cache = _cache(tmp_path, offline=False, transport=transport)

    await cache.get_daily_point(
        latitude=24.36, longitude=90.35, start=date(2020, 1, 1), end=date(2020, 1, 1)
    )

    # One raw-response file plus its provenance sidecar (Task 5:
    # source_url/retrieved_at must survive a later cache replay).
    raw_files = [
        path
        for path in (tmp_path / "cache").glob("*.json")
        if not path.name.endswith(".meta.json")
    ]
    meta_files = list((tmp_path / "cache").glob("*.meta.json"))
    assert len(raw_files) == 1
    assert len(meta_files) == 1


async def test_offline_mode_makes_zero_http_calls(tmp_path: Path) -> None:
    transport = _CountingTransport(_payload())
    cache = _cache(tmp_path, offline=True, transport=transport)

    with pytest.raises(NasaPowerUnavailableOfflineError):
        await cache.get_daily_point(
            latitude=24.36, longitude=90.35, start=date(2020, 1, 1), end=date(2020, 1, 1)
        )

    assert transport.request_count == 0


async def test_offline_cache_hit_works(tmp_path: Path) -> None:
    # Populate the cache while online...
    transport = _CountingTransport(_payload())
    online_cache = _cache(tmp_path, offline=False, transport=transport)
    await online_cache.get_daily_point(
        latitude=24.36, longitude=90.35, start=date(2020, 1, 1), end=date(2020, 1, 1)
    )

    # ...then flip to offline against the same directories.
    offline_transport = _CountingTransport(_payload())
    offline_cache = _cache(tmp_path, offline=True, transport=offline_transport)
    result = await offline_cache.get_daily_point(
        latitude=24.36, longitude=90.35, start=date(2020, 1, 1), end=date(2020, 1, 1)
    )

    assert result.source == "cache"
    assert offline_transport.request_count == 0


async def test_offline_fixture_fallback_works(tmp_path: Path) -> None:
    fixture_dir = tmp_path / "fixtures"
    key = canonical_cache_key(
        latitude=24.36,
        longitude=90.35,
        start=date(2020, 1, 1),
        end=date(2020, 1, 1),
        parameters=("PRECTOTCORR", "T2M_MAX", "T2M_MIN"),
        community="AG",
    )
    _write_fixture_with_manifest(fixture_dir, key=key, payload=_payload())

    transport = _CountingTransport(_payload())
    cache = _cache(tmp_path, offline=True, transport=transport)

    result = await cache.get_daily_point(
        latitude=24.36, longitude=90.35, start=date(2020, 1, 1), end=date(2020, 1, 1)
    )

    assert result.source == "fixture"
    assert transport.request_count == 0
    # Task 5: original NASA provenance survives the fixture replay - it is
    # never replaced with a local file:// path or "now".
    assert result.response.provenance.source_url.startswith("https://power.larc.nasa.gov")
    assert result.response.provenance.retrieved_at.isoformat() == "2020-06-01T00:00:00+00:00"
    assert result.response.provenance.fixture_sha256 is not None
    assert result.response.provenance.local_evidence_path is not None


async def test_fixture_without_manifest_is_rejected(tmp_path: Path) -> None:
    """Task 4: a fixture file with no manifest.json entry at all must
    never be served, even though the bytes on disk are perfectly valid
    JSON - runtime replay trusts the manifest, not just the file."""
    fixture_dir = tmp_path / "fixtures"
    fixture_dir.mkdir(parents=True)
    key = canonical_cache_key(
        latitude=24.36,
        longitude=90.35,
        start=date(2020, 1, 1),
        end=date(2020, 1, 1),
        parameters=("PRECTOTCORR", "T2M_MAX", "T2M_MIN"),
        community="AG",
    )
    (fixture_dir / f"{key}.json").write_text(json.dumps(_payload()), encoding="utf-8")

    transport = _CountingTransport(_payload())
    cache = _cache(tmp_path, offline=True, transport=transport)

    with pytest.raises(NasaEvidenceIntegrityError):
        await cache.get_daily_point(
            latitude=24.36, longitude=90.35, start=date(2020, 1, 1), end=date(2020, 1, 1)
        )
    assert transport.request_count == 0


async def test_tampered_fixture_is_rejected(tmp_path: Path) -> None:
    """Task 4/Task 7: a fixture whose bytes were modified after
    acquisition must be rejected, even with an otherwise well-formed
    manifest entry pointing at it."""
    fixture_dir = tmp_path / "fixtures"
    key = canonical_cache_key(
        latitude=24.36,
        longitude=90.35,
        start=date(2020, 1, 1),
        end=date(2020, 1, 1),
        parameters=("PRECTOTCORR", "T2M_MAX", "T2M_MIN"),
        community="AG",
    )
    _write_fixture_with_manifest(fixture_dir, key=key, payload=_payload())
    # Tamper with the fixture bytes after the manifest was written.
    (fixture_dir / f"{key}.json").write_text(
        json.dumps(_payload(day="20200102")), encoding="utf-8"
    )

    transport = _CountingTransport(_payload())
    cache = _cache(tmp_path, offline=True, transport=transport)

    with pytest.raises(NasaEvidenceIntegrityError, match="Checksum mismatch"):
        await cache.get_daily_point(
            latitude=24.36, longitude=90.35, start=date(2020, 1, 1), end=date(2020, 1, 1)
        )
    assert transport.request_count == 0


async def test_fixture_manifest_entry_marked_synthetic_is_rejected(tmp_path: Path) -> None:
    fixture_dir = tmp_path / "fixtures"
    key = canonical_cache_key(
        latitude=24.36,
        longitude=90.35,
        start=date(2020, 1, 1),
        end=date(2020, 1, 1),
        parameters=("PRECTOTCORR", "T2M_MAX", "T2M_MIN"),
        community="AG",
    )
    _write_fixture_with_manifest(fixture_dir, key=key, payload=_payload(), synthetic=True)

    transport = _CountingTransport(_payload())
    cache = _cache(tmp_path, offline=True, transport=transport)

    with pytest.raises(NasaEvidenceIntegrityError, match="synthetic"):
        await cache.get_daily_point(
            latitude=24.36, longitude=90.35, start=date(2020, 1, 1), end=date(2020, 1, 1)
        )


async def test_offline_with_no_evidence_fails_explicitly(tmp_path: Path) -> None:
    transport = _CountingTransport(_payload())
    cache = _cache(tmp_path, offline=True, transport=transport)

    with pytest.raises(NasaPowerUnavailableOfflineError, match="unavailable offline"):
        await cache.get_daily_point(
            latitude=1.0, longitude=1.0, start=date(2020, 1, 1), end=date(2020, 1, 1)
        )


async def test_corrupted_cache_does_not_become_valid_science(tmp_path: Path) -> None:
    cache_dir = tmp_path / "cache"
    cache_dir.mkdir(parents=True)
    key = canonical_cache_key(
        latitude=24.36,
        longitude=90.35,
        start=date(2020, 1, 1),
        end=date(2020, 1, 1),
        parameters=("PRECTOTCORR", "T2M_MAX", "T2M_MIN"),
        community="AG",
    )
    (cache_dir / f"{key}.json").write_text("{not valid json at all", encoding="utf-8")

    # Online: a corrupted cache entry must be treated as a miss and
    # refetched, not returned as if it were valid.
    transport = _CountingTransport(_payload())
    cache = _cache(tmp_path, offline=False, transport=transport)
    result = await cache.get_daily_point(
        latitude=24.36, longitude=90.35, start=date(2020, 1, 1), end=date(2020, 1, 1)
    )
    assert result.source == "live"
    assert transport.request_count == 1


# ============================================================
# Fixture manifest verification (demo_fixtures/ reproducibility)
# ============================================================


def test_manifest_verification_accepts_matching_checksum(tmp_path: Path) -> None:
    fixture_bytes = json.dumps(_payload()).encode("utf-8")
    (tmp_path / "example.json").write_bytes(fixture_bytes)

    import hashlib

    checksum = hashlib.sha256(fixture_bytes).hexdigest()
    manifest = {
        "provider": "NASA POWER",
        "synthetic": False,
        "files": [
            {
                "file": "example.json",
                "provider": "NASA POWER",
                "dataset_id": "NASA/POWER Source Native Resolution Daily Data",
                "source_url": "https://power.larc.nasa.gov/api/temporal/daily/point?...",
                "endpoint": "/api/temporal/daily/point",
                "request": {"parameters": ["PRECTOTCORR"], "community": "AG"},
                "units": {"PRECTOTCORR": "mm/day"},
                "retrieved_at": "2020-01-01T00:00:00+00:00",
                "sha256": checksum,
                "synthetic": False,
            }
        ],
    }
    (tmp_path / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")

    problems = verify_manifest(tmp_path)

    assert problems == []


def test_manifest_verification_rejects_checksum_mismatch(tmp_path: Path) -> None:
    (tmp_path / "example.json").write_bytes(b'{"tampered": true}')

    manifest = {
        "provider": "NASA POWER",
        "synthetic": False,
        "files": [
            {
                "file": "example.json",
                "provider": "NASA POWER",
                "dataset_id": "x",
                "source_url": "x",
                "endpoint": "x",
                "request": {},
                "units": {},
                "retrieved_at": "2020-01-01T00:00:00+00:00",
                "sha256": "0" * 64,
                "synthetic": False,
            }
        ],
    }
    (tmp_path / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")

    problems = verify_manifest(tmp_path)

    assert len(problems) == 1
    assert "checksum mismatch" in problems[0].lower()


def test_manifest_verification_rejects_synthetic_true(tmp_path: Path) -> None:
    manifest = {"provider": "NASA POWER", "synthetic": True, "files": []}
    (tmp_path / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")

    problems = verify_manifest(tmp_path)

    assert problems == ["Manifest must declare synthetic: false for real NASA demo evidence"]


def test_manifest_verification_rejects_missing_fields(tmp_path: Path) -> None:
    manifest = {
        "provider": "NASA POWER",
        "synthetic": False,
        "files": [{"file": "example.json"}],
    }
    (tmp_path / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")

    problems = verify_manifest(tmp_path)

    assert len(problems) == 1
    assert "missing" in problems[0] and "fields" in problems[0]
