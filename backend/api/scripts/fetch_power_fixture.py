#!/usr/bin/env python
"""Acquires a real NASA POWER Daily Point fixture and its manifest entry.

This is the ONLY sanctioned way to add a file under `demo_fixtures/`. It
always performs a real, live request through the same `NasaPowerClient`
the API uses - never a synthetic file dressed up as NASA data - and it
refuses to write anything if that request does not succeed.

Usage (from `backend/api`), for a fixture `NasaPowerCache` can actually
serve offline - the filename it computes IS the canonical cache key, the
same algorithm `power_cache.canonical_cache_key` uses at request time, so
a fixture written here is found automatically by the exact matching
request, never by hand-naming a file:

    python scripts/fetch_power_fixture.py \\
        --latitude 24.374 --longitude 88.60114 \\
        --start 2001-01-01 --end 2025-12-31 \\
        --fixture-dir ../../demo_fixtures/nasa_power

A one-off file with an arbitrary name (not used for offline serving, e.g.
for manual inspection) can still be written with `--output <path>`
instead of `--fixture-dir`; only `--fixture-dir` output updates
`manifest.json` and only `--fixture-dir` output is guaranteed to be found
by `NasaPowerCache` in offline mode.

No coordinate is hardcoded here. A real pilot-site coordinate (e.g. for
Rajshahi) must come from the caller, sourced from an explicitly documented
location - never invented by this script or by a model.

Manifest: `--fixture-dir` output creates or updates that directory's
`manifest.json` with one entry per real fixture, generated entirely from
the successful request and the downloaded bytes (never hand-typed). Run
with `--verify-manifest <dir>` to re-check every entry's checksum without
fetching anything - this delegates to the exact same
`power_cache.verify_fixture_entry` check the running API uses before
serving a fixture offline, so there is only one integrity algorithm.
"""

from __future__ import annotations

import argparse
import asyncio
import contextlib
import hashlib
import json
import sys
from datetime import date, datetime
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
BACKEND_API_ROOT = SCRIPT_DIR.parent
sys.path.insert(0, str(BACKEND_API_ROOT))

from app.integrations.nasa.client import (  # noqa: E402
    DEFAULT_PARAMETERS,
    NasaPowerClient,
    NasaPowerError,
)
from app.integrations.nasa.power_cache import (  # noqa: E402
    MANIFEST_FILENAME,
    NasaEvidenceIntegrityError,
    canonical_cache_key,
    load_manifest,
    verify_fixture_entry,
)


def _parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--latitude", type=float)
    parser.add_argument("--longitude", type=float)
    parser.add_argument("--start", type=str, help="YYYY-MM-DD")
    parser.add_argument("--end", type=str, help="YYYY-MM-DD")
    parser.add_argument(
        "--fixture-dir",
        type=str,
        default=None,
        help=(
            "Write <canonical_cache_key>.json here and update manifest.json "
            "- the filename NasaPowerCache will actually look for offline."
        ),
    )
    parser.add_argument(
        "--output",
        type=str,
        default=None,
        help="Write to this exact path instead (no manifest update, not offline-discoverable)",
    )
    parser.add_argument(
        "--parameters",
        type=str,
        default=None,
        help=f"Comma-separated NASA POWER parameter names (default: {','.join(DEFAULT_PARAMETERS)})",
    )
    parser.add_argument("--community", type=str, default="AG")
    parser.add_argument("--base-url", type=str, default="https://power.larc.nasa.gov")
    parser.add_argument("--timeout-seconds", type=float, default=30.0)
    parser.add_argument(
        "--verify-manifest",
        type=str,
        default=None,
        help="Instead of fetching, verify every entry in <dir>/manifest.json",
    )
    return parser.parse_args(argv)


def _sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


async def _fetch(args: argparse.Namespace) -> int:
    missing = [
        name
        for name, value in (
            ("--latitude", args.latitude),
            ("--longitude", args.longitude),
            ("--start", args.start),
            ("--end", args.end),
        )
        if value is None
    ]
    if missing:
        print(f"Missing required arguments: {', '.join(missing)}", file=sys.stderr)
        return 2
    if not args.fixture_dir and not args.output:
        print("Exactly one of --fixture-dir or --output is required", file=sys.stderr)
        return 2
    if args.fixture_dir and args.output:
        print("Pass only one of --fixture-dir or --output, not both", file=sys.stderr)
        return 2

    start = date.fromisoformat(args.start)
    end = date.fromisoformat(args.end)
    parameters = (
        tuple(part.strip() for part in args.parameters.split(","))
        if args.parameters
        else DEFAULT_PARAMETERS
    )

    client = NasaPowerClient(base_url=args.base_url, timeout_seconds=args.timeout_seconds)
    try:
        response = await client.fetch_daily_point(
            latitude=args.latitude,
            longitude=args.longitude,
            start=start,
            end=end,
            parameters=parameters,
            community=args.community,
        )
    except NasaPowerError as exc:
        print(
            "Real NASA POWER demo fixture not generated because live "
            f"retrieval could not be verified: {exc}",
            file=sys.stderr,
        )
        return 1
    finally:
        await client.aclose()

    provenance = response.provenance

    if args.fixture_dir:
        fixture_dir = Path(args.fixture_dir)
        if not fixture_dir.is_absolute():
            fixture_dir = (BACKEND_API_ROOT / fixture_dir).resolve()
        key = canonical_cache_key(
            latitude=args.latitude,
            longitude=args.longitude,
            start=start,
            end=end,
            parameters=parameters,
            community=args.community,
        )
        output_path = fixture_dir / f"{key}.json"
    else:
        output_path = Path(args.output)
        if not output_path.is_absolute():
            output_path = (BACKEND_API_ROOT / output_path).resolve()
        key = None

    output_path.parent.mkdir(parents=True, exist_ok=True)
    raw_bytes = json.dumps(response.raw, sort_keys=True, indent=2).encode("utf-8")
    output_path.write_bytes(raw_bytes)
    checksum = _sha256_bytes(raw_bytes)

    if args.fixture_dir:
        _update_manifest(
            manifest_dir=output_path.parent,
            file_name=output_path.name,
            provenance_source_url=provenance.source_url,
            endpoint=provenance.endpoint,
            dataset_id=provenance.dataset_id,
            community=provenance.community,
            parameters=list(provenance.parameters),
            latitude=provenance.latitude,
            longitude=provenance.longitude,
            start_date=provenance.start_date,
            end_date=provenance.end_date,
            time_standard=provenance.time_standard,
            units=provenance.units,
            retrieved_at=provenance.retrieved_at,
            checksum=checksum,
        )

    print("NASA POWER fixture created")
    print(f"Source: {provenance.source_url}")
    print(f"Parameters: {', '.join(provenance.parameters)}")
    print(f"Period: {provenance.start_date.isoformat()} - {provenance.end_date.isoformat()}")
    print(f"Location: {provenance.latitude}, {provenance.longitude}")
    print(f"Time standard: {provenance.time_standard}")
    print(f"SHA-256: {checksum}")
    if key is not None:
        print(f"Canonical cache key: {key}")
    return 0


def _update_manifest(
    *,
    manifest_dir: Path,
    file_name: str,
    provenance_source_url: str,
    endpoint: str,
    dataset_id: str,
    community: str,
    parameters: list[str],
    latitude: float,
    longitude: float,
    start_date: date,
    end_date: date,
    time_standard: str,
    units: dict[str, str],
    retrieved_at: datetime,
    checksum: str,
) -> None:
    manifest_path = manifest_dir / MANIFEST_FILENAME
    manifest: dict = {"provider": "NASA POWER", "synthetic": False, "files": []}
    if manifest_path.exists():
        with contextlib.suppress(json.JSONDecodeError):
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            # corrupted manifest falls through to the default above

    entry = {
        "file": file_name,
        "provider": "NASA POWER",
        "dataset_id": dataset_id,
        "source_url": provenance_source_url,
        "endpoint": endpoint,
        "request": {
            "parameters": parameters,
            "community": community,
            "latitude": latitude,
            "longitude": longitude,
            "start": start_date.strftime("%Y%m%d"),
            "end": end_date.strftime("%Y%m%d"),
            "format": "JSON",
            "time-standard": time_standard,
        },
        "units": units,
        "retrieved_at": retrieved_at.isoformat(),
        "sha256": checksum,
        "synthetic": False,
    }

    manifest["files"] = [f for f in manifest.get("files", []) if f.get("file") != file_name]
    manifest["files"].append(entry)
    manifest["files"].sort(key=lambda item: item["file"])

    manifest_path.write_text(json.dumps(manifest, sort_keys=True, indent=2), encoding="utf-8")


def verify_manifest(manifest_dir: Path) -> list[str]:
    """Re-verifies every real fixture the manifest claims, via the exact
    same `power_cache.verify_fixture_entry` check the running API uses
    before serving a fixture offline - one integrity algorithm, not two.
    Returns a list of human-readable problems; an empty list means every
    entry verified cleanly.
    """
    manifest = load_manifest(manifest_dir)
    if manifest is None:
        return [f"No {MANIFEST_FILENAME} found in {manifest_dir}"]
    if manifest.get("synthetic") is not False:
        return ["Manifest must declare synthetic: false for real NASA demo evidence"]

    problems: list[str] = []
    for entry in manifest.get("files", []):
        file_name = entry.get("file", "<unknown>")
        try:
            verify_fixture_entry(manifest_dir, file_name)
        except NasaEvidenceIntegrityError as exc:
            problems.append(str(exc))
    return problems


def _run_verify(manifest_dir: str) -> int:
    problems = verify_manifest(Path(manifest_dir))
    if problems:
        for problem in problems:
            print(f"FAIL: {problem}", file=sys.stderr)
        return 1
    print(f"All manifest entries verified in {manifest_dir}")
    return 0


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv if argv is not None else sys.argv[1:])
    if args.verify_manifest:
        return _run_verify(args.verify_manifest)
    return asyncio.run(_fetch(args))


if __name__ == "__main__":
    raise SystemExit(main())
