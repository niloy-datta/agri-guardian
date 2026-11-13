"""Money value object.

Money is an integer count of minor units plus an ISO-4217 code. Floats are
never used: BDT 52.35 is `Money(5235, "BDT")`, not `52.35`.
"""

from dataclasses import dataclass
from decimal import Decimal

# Currencies whose minor unit is not 1/100. Extended as country packs land.
_MINOR_UNIT_EXPONENTS: dict[str, int] = {
    "JPY": 0,
    "KRW": 0,
    "VND": 0,
    "CLP": 0,
    "ISK": 0,
    "KWD": 3,
    "BHD": 3,
    "OMR": 3,
    "JOD": 3,
    "TND": 3,
}
_DEFAULT_MINOR_UNIT_EXPONENT = 2


class MoneyError(ValueError):
    pass


@dataclass(frozen=True, slots=True)
class Money:
    amount_minor: int
    currency: str

    def __post_init__(self) -> None:
        if not isinstance(self.amount_minor, int) or isinstance(self.amount_minor, bool):
            raise MoneyError("amount_minor must be an integer number of minor units")
        if not (isinstance(self.currency, str) and len(self.currency) == 3):
            raise MoneyError("currency must be a 3-letter ISO-4217 code")
        object.__setattr__(self, "currency", self.currency.upper())

    @property
    def minor_unit_exponent(self) -> int:
        return _MINOR_UNIT_EXPONENTS.get(self.currency, _DEFAULT_MINOR_UNIT_EXPONENT)

    def to_decimal(self) -> Decimal:
        """Exact major-unit value, for display and invoices only."""
        return Decimal(self.amount_minor).scaleb(-self.minor_unit_exponent)

    @classmethod
    def from_decimal(cls, amount: Decimal | str, currency: str) -> "Money":
        currency = currency.upper()
        exponent = _MINOR_UNIT_EXPONENTS.get(currency, _DEFAULT_MINOR_UNIT_EXPONENT)
        scaled = Decimal(amount).scaleb(exponent)
        if scaled != scaled.to_integral_value():
            raise MoneyError(
                f"{amount} has more precision than {currency} supports "
                f"({exponent} minor digits)"
            )
        return cls(int(scaled), currency)

    def _assert_same_currency(self, other: "Money") -> None:
        if self.currency != other.currency:
            raise MoneyError(f"Cannot combine {self.currency} with {other.currency}")

    def __add__(self, other: "Money") -> "Money":
        self._assert_same_currency(other)
        return Money(self.amount_minor + other.amount_minor, self.currency)

    def __sub__(self, other: "Money") -> "Money":
        self._assert_same_currency(other)
        return Money(self.amount_minor - other.amount_minor, self.currency)

    def __str__(self) -> str:
        return f"{self.to_decimal()} {self.currency}"
