"""Provider evidence for catalogued dataset identifiers.

Captured live on 2026-11-13 from
`https://cmr.earthdata.nasa.gov/search/collections.json?short_name=..&version=..`
(exactly one collection returned for every pair) and
`/search/concepts/<concept_id>.umm_json` (DOI). AppEEARS product ids and
layer names were checked against keyless
`https://appeears.earthdatacloud.nasa.gov/api/product[/<id>]`.
Re-run `scripts/verify_dataset_ids.py` to refresh.
"""

from __future__ import annotations

from dataclasses import dataclass

VERIFIED_ON = "2026-11-13"


@dataclass(frozen=True, slots=True)
class CmrEvidence:
    concept_id: str
    data_center: str
    doi: str

    @property
    def doi_url(self) -> str:
        return f"https://doi.org/{self.doi}"

    @property
    def cmr_url(self) -> str:
        return f"https://cmr.earthdata.nasa.gov/search/concepts/{self.concept_id}.html"


CMR_EVIDENCE: dict[tuple[str, str], CmrEvidence] = {
    ("HLSS30", "2.0"): CmrEvidence("C2021957295-LPCLOUD", "LPCLOUD", "10.5067/HLS/HLSS30.002"),
    ("HLSL30", "2.0"): CmrEvidence("C2021957657-LPCLOUD", "LPCLOUD", "10.5067/HLS/HLSL30.002"),
    ("SPL3SMP_E", "006"): CmrEvidence("C2938664763-NSIDC_CPRD", "NSIDC_CPRD", "10.5067/M20OXIZHY3RJ"),
    ("VJ113A1", "002"): CmrEvidence("C2519122065-LPCLOUD", "LPCLOUD", "10.5067/VIIRS/VJ113A1.002"),
    ("SPL4SMGP", "008"): CmrEvidence("C3480440870-NSIDC_CPRD", "NSIDC_CPRD", "10.5067/T5RUATAQREF8"),
    ("GPM_3IMERGDF", "07"): CmrEvidence("C2723754864-GES_DISC", "GES_DISC", "10.5067/GPM/IMERGDF/DAY/07"),
    ("GPM_3IMERGDL", "07"): CmrEvidence("C2723754859-GES_DISC", "GES_DISC", "10.5067/GPM/IMERGDL/DAY/07"),
    ("MOD13Q1", "061"): CmrEvidence("C1748066515-LPCLOUD", "LPCLOUD", "10.5067/MODIS/MOD13Q1.061"),
    ("MCD12Q2", "061"): CmrEvidence("C2484079943-LPCLOUD", "LPCLOUD", "10.5067/MODIS/MCD12Q2.061"),
    ("MCD12Q1", "061"): CmrEvidence("C2484079608-LPCLOUD", "LPCLOUD", "10.5067/MODIS/MCD12Q1.061"),
    ("MOD16A2GF", "061"): CmrEvidence("C2565791021-LPCLOUD", "LPCLOUD", "10.5067/MODIS/MOD16A2GF.061"),
    ("MOD11A1", "061"): CmrEvidence("C1748058432-LPCLOUD", "LPCLOUD", "10.5067/MODIS/MOD11A1.061"),
    ("OPERA_L3_DSWX-HLS_V1", "1.0"): CmrEvidence("C2617126679-POCLOUD", "POCLOUD", "10.5067/OPDSW-PL3V1"),
    ("NASADEM_HGT", "001"): CmrEvidence(
        "C2763264762-LPCLOUD", "LPCLOUD", "10.5067/MEASURES/NASADEM/NASADEM_HGT.001"
    ),
    ("GLDAS_NOAH025_3H", "2.1"): CmrEvidence("C1342986035-GES_DISC", "GES_DISC", "10.5067/E7TYRXPJKWOQ"),
    ("FLDAS_NOAH01_C_GL_M", "001"): CmrEvidence("C1563089663-GES_DISC", "GES_DISC", "10.5067/5NHC22T9375G"),
}  # fmt: skip

APPEEARS_VERIFIED: frozenset[str] = frozenset({
    "HLSS30.020", "HLSL30.020", "SPL4SMGP.008", "SPL3SMP_E.006", "MOD13Q1.061",
    "MCD12Q2.061", "MCD12Q1.061", "MOD16A2GF.061", "MOD11A1.061", "VJ113A1.002",
})  # fmt: skip
