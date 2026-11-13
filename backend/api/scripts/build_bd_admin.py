"""Rebuild `app/integrations/reference/data/bd_districts.json`.

Inputs (all keyless):
  * GeoNames dump https://download.geonames.org/export/dump/BD.zip
    (CC BY 4.0) - district/division ids, centroids, parent division.
  * geoBoundaries gbOpen BGD ADM2 simplified (CC BY 3.0 IGO, build
    2023-12-12) - district polygons.
  * geoBoundaries gbOpen BGD ADM0 simplified (CC0) - national outline.

Usage: python scripts/build_bd_admin.py <BD.txt> <adm2.geojson> <adm0.geojson>

The three sources spell districts differently; `CANONICAL` maps every
spelling to one canonical English name (the spelling BAMIS uses where it
differs), so the join is explicit and fails loudly on anything unmapped.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

DIVISIONS = {
    "81": "Dhaka", "82": "Khulna", "83": "Rajshahi", "84": "Chattogram",
    "85": "Barishal", "86": "Sylhet", "87": "Rangpur", "H": "Mymensingh",
}  # fmt: skip

CANONICAL = {
    "Bogra": "Bogura", "Jessore": "Jashore", "Chittagong": "Chattogram",
    "Chapai Nababganj": "Chapainawabganj", "Nawabganj": "Chapainawabganj",
    "Netrakona": "Netrokona", "Maulvibazar": "Moulvibazar", "Kishoreganj": "Kishoregonj",
    "Khagrachhari": "Khagrachari", "Pirojpur": "Pirujpur", "Jhalokati": "Jhalakati",
    "Brahmanbaria": "Bramanbaria", "Brahamanbaria": "Bramanbaria", "Manikganj": "Manikgonj",
    "Barisal": "Barishal", "Nilphamari Zila": "Nilphamari",
    "Lalmonirhat District": "Lalmonirhat", "Cox's Bazar": "Coxsbazar", "Comilla": "Cumilla",
}  # fmt: skip


def canon(name: str) -> str:
    return CANONICAL.get(name, name)


def _round(geom: dict) -> list:
    polys = geom["coordinates"] if geom["type"] == "MultiPolygon" else [geom["coordinates"]]
    return [[[[round(x, 4), round(y, 4)] for x, y in ring] for ring in poly] for poly in polys]


def main(bd_txt: Path, adm2: Path, adm0: Path, out: Path) -> None:
    districts: dict[str, dict] = {}
    for line in bd_txt.read_text(encoding="utf-8").splitlines():
        f = line.split("\t")
        if f[6] == "A" and f[7] == "ADM2":
            name = canon(f[1])
            districts[name] = {
                "name": name,
                "geonames_id": int(f[0]),
                "geonames_name": f[1],
                "division": DIVISIONS[f[10]],
                "centroid": [float(f[4]), float(f[5])],
            }
    shapes = json.loads(adm2.read_text(encoding="utf-8"))["features"]
    for feat in shapes:
        name = canon(feat["properties"]["shapeName"])
        if name not in districts:
            raise SystemExit(f"unmapped geoBoundaries district: {feat['properties']['shapeName']}")
        districts[name]["geoboundaries_name"] = feat["properties"]["shapeName"]
        districts[name]["polygons"] = _round(feat["geometry"])
    missing = [n for n, d in districts.items() if "polygons" not in d]
    if len(districts) != 64 or missing:
        raise SystemExit(f"expected 64 joined districts, got {len(districts)}; missing {missing}")
    national = json.loads(adm0.read_text(encoding="utf-8"))["features"][0]["geometry"]
    payload = {
        "sources": {
            "geonames": "https://download.geonames.org/export/dump/BD.zip (CC BY 4.0)",
            "adm2": "geoBoundaries gbOpen BGD ADM2, build 2023-12-12 (CC BY 3.0 IGO)",
            "adm0": "geoBoundaries gbOpen BGD ADM0, build 2023-12-12 (CC0 1.0)",
        },
        "divisions": sorted(set(DIVISIONS.values())),
        "national_polygons": _round(national),
        "districts": sorted(districts.values(), key=lambda d: d["name"]),
    }
    out.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
    print(f"wrote {len(districts)} districts to {out}")


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[1]
    main(*(Path(a) for a in sys.argv[1:4]),
         root / "app/integrations/reference/data/bd_districts.json")  # fmt: skip
