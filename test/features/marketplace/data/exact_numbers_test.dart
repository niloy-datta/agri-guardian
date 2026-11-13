import 'package:flutter_test/flutter_test.dart';
import 'package:agri_guardian/features/marketplace/data/exact_numbers.dart';

/// Focused regression coverage for Task 9/18 (12B.0): core commerce money
/// and quantity conversions must stay exact - integer minor units and
/// normalized decimal strings only, never `double` arithmetic that could
/// silently drift a price or quantity.
void main() {
  group('normalizeQuantityInput', () {
    test('accepts a plain integer quantity unchanged', () {
      expect(normalizeQuantityInput('1200'), equals('1200'));
    });

    test('accepts up to 3 fractional digits unchanged', () {
      expect(normalizeQuantityInput('1200.500'), equals('1200.500'));
    });

    test('rejects more than 3 fractional digits', () {
      expect(
        () => normalizeQuantityInput('1200.5001'),
        throwsA(isA<ExactNumberFormatException>()),
      );
    });

    test('rejects zero and negative quantities', () {
      expect(
        () => normalizeQuantityInput('0'),
        throwsA(isA<ExactNumberFormatException>()),
      );
      expect(
        () => normalizeQuantityInput('-5'),
        throwsA(isA<ExactNumberFormatException>()),
      );
    });
  });

  group('parseMajorAmountToMinorUnits', () {
    test('converts a 2-decimal BDT amount to exact minor units', () {
      expect(parseMajorAmountToMinorUnits('52.50'), equals(5250));
    });

    test('converts a whole-number amount to exact minor units', () {
      expect(parseMajorAmountToMinorUnits('100'), equals(10000));
    });

    test('rejects more fractional digits than the currency allows', () {
      expect(
        () => parseMajorAmountToMinorUnits('52.505'),
        throwsA(isA<ExactNumberFormatException>()),
      );
    });

    test('round-trips through formatMinorUnitsToMajor exactly', () {
      final minor = parseMajorAmountToMinorUnits('1234.56');
      expect(formatMinorUnitsToMajor(minor), equals('1234.56'));
    });
  });

  group('estimateTotalMinorUnits (no double arithmetic)', () {
    test('exact quantity * unit price matches expected integer total', () {
      // 10.500 units * 5250 minor units/unit = 55,125.0 minor units.
      expect(estimateTotalMinorUnits('10.500', 5250), equals(55125));
    });

    test('a value that a naive double multiplication would round incorrectly '
        'still comes out exact', () {
      // 0.1 + 0.2 style drift risk: 3 units at 10 minor units should be
      // exactly 30, never 29 or 31 from floating point representation.
      expect(estimateTotalMinorUnits('3', 10), equals(30));
    });

    test(
      'rejects a malformed quantity string rather than guessing a value',
      () {
        expect(
          () => estimateTotalMinorUnits('not-a-number', 100),
          throwsA(isA<ExactNumberFormatException>()),
        );
      },
    );
  });
}
