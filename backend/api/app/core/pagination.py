"""Cursor pagination shared by every module that lists domain collections
(fields, listings, orders, notifications, ...).

The cursor encodes `(created_at, id)` of the last row seen, base64url-safe,
opaque to clients. Offset pagination is intentionally not offered - it does
not scale to hundreds of thousands of rows per farmer/buyer.
"""

import base64
import binascii
import json
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel

DEFAULT_PAGE_SIZE = 20
MAX_PAGE_SIZE = 100


class CursorPage[T](BaseModel):
    items: list[T]
    next_cursor: str | None = None
    has_more: bool = False


def encode_cursor(created_at: datetime, row_id: UUID) -> str:
    payload = json.dumps([created_at.isoformat(), str(row_id)]).encode("utf-8")
    return base64.urlsafe_b64encode(payload).decode("ascii")


def decode_cursor(cursor: str) -> tuple[datetime, UUID]:
    try:
        raw = base64.urlsafe_b64decode(cursor.encode("ascii"))
        created_at_str, row_id_str = json.loads(raw)
        return datetime.fromisoformat(created_at_str), UUID(row_id_str)
    except (ValueError, binascii.Error, json.JSONDecodeError) as exc:
        raise ValueError("Invalid pagination cursor") from exc


def clamp_page_size(requested: int | None) -> int:
    if requested is None:
        return DEFAULT_PAGE_SIZE
    return max(1, min(requested, MAX_PAGE_SIZE))
