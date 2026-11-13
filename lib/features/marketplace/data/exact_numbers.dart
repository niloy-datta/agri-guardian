/// Exact string/integer arithmetic for marketplace money and quantity.
///
/// Task 13/14/15: `unit_price_minor`, `asking_price_minor`, and
/// `total_amount_minor` are never doubles - a double cannot represent
/// every integer minor-unit value exactly once amounts get large, and
/// `double.parse(price) * 100` can silently produce e.g. 5249 instead of
/// 5250 for certain inputs. Everything here works on strings/`BigInt`/
/// `int` only.
library;

/// Thrown when a user-entered amount or quantity string cannot be
/// interpreted safely - never silently coerced to a guessed value.
class ExactNumberFormatException implements Exception {
  final String message;
  const ExactNumberFormatException(this.message);

  @override
  String toString() => message;
}

final RegExp _decimalPattern = RegExp(r'^-?\d+(\.\d+)?$');

/// Normalizes a quantity string to the backend's exact convention
/// (`NUMERIC(18,3)`): at most 3 fractional digits, strictly positive, no
/// scientific notation, no leading/trailing garbage. Returns the
/// normalized string unchanged in scale (does not pad/strip trailing
/// zeros) so what the user typed is what gets sent.
String normalizeQuantityInput(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    throw const ExactNumberFormatException('পরিমাণ লিখুন।');
  }
  if (!_decimalPattern.hasMatch(trimmed)) {
    throw const ExactNumberFormatException(
      'পরিমাণ সঠিক সংখ্যা হতে হবে (যেমন: 1200 বা 1200.5)।',
    );
  }
  if (trimmed.startsWith('-')) {
    throw const ExactNumberFormatException('পরিমাণ ঋণাত্মক হতে পারবে না।');
  }
  final dotIndex = trimmed.indexOf('.');
  if (dotIndex != -1 && trimmed.length - dotIndex - 1 > 3) {
    throw const ExactNumberFormatException(
      'পরিমাণে সর্বোচ্চ ৩ দশমিক ঘর থাকতে পারবে।',
    );
  }
  final value = num.tryParse(trimmed);
  if (value == null || value.isNaN || value.isInfinite || value <= 0) {
    throw const ExactNumberFormatException(
      'পরিমাণ শূন্যের চেয়ে বেশি হতে হবে।',
    );
  }
  return trimmed;
}

/// Converts a major-unit currency string (e.g. "52.50") the user typed
/// into an exact integer count of minor units (e.g. 5250 for a
/// 2-fraction-digit currency), using only integer/string arithmetic.
///
/// `fractionDigits` is the currency's minor-unit exponent (2 for BDT/USD,
/// 0 for JPY, etc. - see `app/shared/money.py`'s `_MINOR_UNIT_EXPONENTS`
/// for the backend's authoritative list; this client only ever needs the
/// BDT default in this phase).
int parseMajorAmountToMinorUnits(String input, {int fractionDigits = 2}) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    throw const ExactNumberFormatException('মূল্য লিখুন।');
  }
  if (!_decimalPattern.hasMatch(trimmed) || trimmed.startsWith('-')) {
    throw const ExactNumberFormatException(
      'মূল্য সঠিক সংখ্যা হতে হবে (যেমন: 52.50)।',
    );
  }

  final dotIndex = trimmed.indexOf('.');
  final wholePart = dotIndex == -1 ? trimmed : trimmed.substring(0, dotIndex);
  var fractionPart = dotIndex == -1 ? '' : trimmed.substring(dotIndex + 1);
  if (fractionPart.length > fractionDigits) {
    throw ExactNumberFormatException(
      'মূল্যে সর্বোচ্চ $fractionDigits দশমিক ঘর থাকতে পারবে।',
    );
  }
  fractionPart = fractionPart.padRight(fractionDigits, '0');

  final whole = BigInt.parse(wholePart.isEmpty ? '0' : wholePart);
  final fraction = BigInt.parse(fractionPart.isEmpty ? '0' : fractionPart);
  final scale = BigInt.from(10).pow(fractionDigits);
  final minorUnits = whole * scale + fraction;

  // BigInt.from(9223372036854775807) fails to compile on web: dart2js/DDC
  // represent Dart int literals as JS doubles, which cannot hold this
  // value exactly. BigInt.parse reads it digit-by-digit at runtime
  // instead, so it never passes through a lossy JS number literal.
  if (minorUnits > BigInt.parse('9223372036854775807')) {
    throw const ExactNumberFormatException('মূল্য অত্যধিক বড়।');
  }
  return minorUnits.toInt();
}

/// Exact client-side estimate of `quantity * unit_price_minor`, rounded
/// half-away-from-zero to the nearest whole minor unit - the same rule
/// `app/modules/orders/service.py::compute_total_amount_minor` uses on
/// the backend (see `ROUNDING_RULE` there). Never a `double`: the
/// quantity string (up to 3 fractional digits) is scaled into a `BigInt`
/// alongside the integer minor-unit price, so this display estimate can
/// never drift from what the server will actually compute at acceptance
/// time (Task 13/42's "exact client-side estimated total").
int estimateTotalMinorUnits(String quantity, int unitPriceMinor) {
  final trimmed = quantity.trim();
  if (!_decimalPattern.hasMatch(trimmed) || trimmed.startsWith('-')) {
    throw const ExactNumberFormatException('পরিমাণ সঠিক সংখ্যা হতে হবে।');
  }
  const scaleDigits = 3;
  final dotIndex = trimmed.indexOf('.');
  final wholePart = dotIndex == -1 ? trimmed : trimmed.substring(0, dotIndex);
  final fractionPart = (dotIndex == -1 ? '' : trimmed.substring(dotIndex + 1))
      .padRight(scaleDigits, '0');

  final scale = BigInt.from(10).pow(scaleDigits);
  final quantityScaled =
      BigInt.parse(wholePart.isEmpty ? '0' : wholePart) * scale +
      BigInt.parse(fractionPart.substring(0, scaleDigits));

  final exactScaled = quantityScaled * BigInt.from(unitPriceMinor);
  // Round-half-away-from-zero when dividing back down by `scale`.
  final half = scale ~/ BigInt.two;
  final rounded = exactScaled.isNegative
      ? (exactScaled - half) ~/ scale
      : (exactScaled + half) ~/ scale;
  return rounded.toInt();
}

/// The inverse of [parseMajorAmountToMinorUnits]: an exact major-unit
/// display string for an integer minor-unit amount. Never touches a
/// double.
String formatMinorUnitsToMajor(int minorUnits, {int fractionDigits = 2}) {
  final negative = minorUnits < 0;
  final absValue = BigInt.from(minorUnits).abs();
  final scale = BigInt.from(10).pow(fractionDigits);
  final whole = absValue ~/ scale;
  final fraction = absValue % scale;
  final sign = negative ? '-' : '';
  if (fractionDigits == 0) {
    return '$sign$whole';
  }
  final fractionStr = fraction.toString().padLeft(fractionDigits, '0');
  return '$sign$whole.$fractionStr';
}
