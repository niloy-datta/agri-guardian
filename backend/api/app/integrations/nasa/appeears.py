"""NASA AppEEARS: field-polygon and point satellite extraction (MODIS NDVI,
ET, LST, ...), computed server-side and delivered as files.

Verified live without credentials: `GET /product` (list of products with
`Product`, `Platform`, `Description`, `Resolution`, `TemporalGranularity`,
`Version`, `Available`) and `GET /product/{Product.Version}` (a dict of
layer name -> metadata incl. `FillValue`, `DataType`, `Description`).

**Unverified against a live account:** `POST /login` (HTTP Basic with
Earthdata username/password -> bearer `token`), `POST /task` (task_type
`area` or `point`), `GET /task/{id}` and `GET /bundle/{id}` follow
AppEEARS's published API but were not executed here because they need an
Earthdata login. Task submission is asynchronous: submit, poll
`get_task`, then download from the bundle. Run
`scripts/integration_smoke.py` with credentials to confirm.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
from typing import Any

from app.integrations.common.errors import (
    IntegrationCredentialsMissingError,
    IntegrationResponseError,
    IntegrationValidationError,
)
from app.integrations.common.geo import (
    validate_date_range,
    validate_lat_lon,
    validate_polygon_geojson,
)
from app.integrations.common.http import Provenance, ProviderHttp

PROVIDER = "NASA AppEEARS"
_OUTPUT_FORMATS = frozenset({"geotiff", "netcdf4"})


@dataclass(frozen=True, slots=True)
class AppeearsProduct:
    product: str
    version: str
    platform: str | None
    description: str | None
    resolution: str | None
    temporal_granularity: str | None
    available: bool
    raw: dict[str, Any] = field(repr=False)

    @property
    def product_id(self) -> str:
        """The `Product.Version` id AppEEARS uses in layer specs."""
        return f"{self.product}.{self.version}"


@dataclass(frozen=True, slots=True)
class AppeearsTask:
    task_id: str
    status: str | None
    raw: dict[str, Any] = field(repr=False)


class AppeearsClient:
    def __init__(
        self,
        *,
        base_url: str,
        username: str,
        password: str,
        http: ProviderHttp,
    ) -> None:
        self._base = base_url.rstrip("/")
        self._username = username
        self._password = password
        self._http = http
        self._token: str | None = None

    # -- keyless ---------------------------------------------------------

    async def list_products(self) -> tuple[list[AppeearsProduct], Provenance]:
        result = await self._http.get(f"{self._base}/product", dataset="AppEEARS products")
        body = result.json()
        if not isinstance(body, list):
            raise IntegrationResponseError("product list was not a list", provider=PROVIDER)
        products = [
            AppeearsProduct(
                product=str(p["Product"]),
                version=str(p["Version"]),
                platform=p.get("Platform"),
                description=p.get("Description"),
                resolution=p.get("Resolution"),
                temporal_granularity=p.get("TemporalGranularity"),
                available=bool(p.get("Available", False)),
                raw=p,
            )
            for p in body
        ]
        return products, result.provenance

    async def list_layers(self, product_id: str) -> dict[str, dict[str, Any]]:
        """Layers for e.g. `MOD13Q1.061`, keyed by layer name."""
        result = await self._http.get(
            f"{self._base}/product/{product_id}", dataset=f"AppEEARS {product_id} layers"
        )
        body = result.json()
        if not isinstance(body, dict):
            raise IntegrationResponseError("layer list was not an object", provider=PROVIDER)
        return body

    # -- authenticated ---------------------------------------------------

    async def login(self) -> str:
        if not self._username or not self._password:
            raise IntegrationCredentialsMissingError(
                "NASA Earthdata username/password are required for AppEEARS tasks",
                provider=PROVIDER,
            )
        result = await self._http.post(
            f"{self._base}/login",
            dataset="AppEEARS login",
            basic_auth=(self._username, self._password),
            data={"grant_type": "client_credentials"},
        )
        body = result.json()
        token = body.get("token") if isinstance(body, dict) else None
        if not token:
            raise IntegrationResponseError("login response had no token", provider=PROVIDER)
        self._token = str(token)
        return self._token

    async def submit_area_task(
        self,
        *,
        name: str,
        polygon: dict[str, Any],
        start: date,
        end: date,
        layers: list[tuple[str, str]],
        output_format: str = "geotiff",
    ) -> AppeearsTask:
        """`polygon` is a GeoJSON Polygon/MultiPolygon (the field boundary).
        `layers` is a list of (product_id, layer), e.g.
        `[("MOD13Q1.061", "_250m_16_days_NDVI")]`."""
        validate_polygon_geojson(polygon, provider=PROVIDER)
        params = self._common_params(start, end, layers)
        params["geo"] = {
            "type": "FeatureCollection",
            "features": [{"type": "Feature", "properties": {}, "geometry": polygon}],
        }
        params["output"] = {
            "format": {"type": self._format(output_format)},
            "projection": "geographic",
        }
        return await self._submit("area", name, params)

    async def submit_point_task(
        self,
        *,
        name: str,
        points: list[tuple[str, float, float]],
        start: date,
        end: date,
        layers: list[tuple[str, str]],
    ) -> AppeearsTask:
        """`points` is a list of (id, latitude, longitude)."""
        if not points:
            raise IntegrationValidationError("provide at least one point", provider=PROVIDER)
        for _, lat, lon in points:
            validate_lat_lon(lat, lon, provider=PROVIDER)
        params = self._common_params(start, end, layers)
        params["coordinates"] = [
            {"id": pid, "latitude": lat, "longitude": lon, "category": "field"}
            for pid, lat, lon in points
        ]
        return await self._submit("point", name, params)

    async def get_task(self, task_id: str) -> AppeearsTask:
        result = await self._http.get(
            f"{self._base}/task/{task_id}",
            dataset="AppEEARS task",
            bearer=await self._bearer(),
        )
        body = result.json()
        return AppeearsTask(
            task_id=str(body.get("task_id", task_id)), status=body.get("status"), raw=body
        )

    # -- internals -------------------------------------------------------

    async def _bearer(self) -> str:
        return self._token or await self.login()

    async def _submit(self, task_type: str, name: str, params: dict[str, Any]) -> AppeearsTask:
        if not name:
            raise IntegrationValidationError("task name is required", provider=PROVIDER)
        result = await self._http.post(
            f"{self._base}/task",
            dataset=f"AppEEARS {task_type} task",
            json_body={"task_type": task_type, "task_name": name, "params": params},
            bearer=await self._bearer(),
        )
        body = result.json()
        task_id = body.get("task_id") if isinstance(body, dict) else None
        if not task_id:
            raise IntegrationResponseError("task response had no task_id", provider=PROVIDER)
        return AppeearsTask(task_id=str(task_id), status=body.get("status"), raw=body)

    @staticmethod
    def _common_params(start: date, end: date, layers: list[tuple[str, str]]) -> dict[str, Any]:
        validate_date_range(start, end, provider=PROVIDER)
        if not layers:
            raise IntegrationValidationError("provide at least one layer", provider=PROVIDER)
        return {
            "dates": [
                {"startDate": start.strftime("%m-%d-%Y"), "endDate": end.strftime("%m-%d-%Y")}
            ],
            "layers": [{"product": product, "layer": layer} for product, layer in layers],
        }

    @staticmethod
    def _format(output_format: str) -> str:
        if output_format not in _OUTPUT_FORMATS:
            raise IntegrationValidationError(
                f"output_format must be one of {sorted(_OUTPUT_FORMATS)}", provider=PROVIDER
            )
        return output_format
