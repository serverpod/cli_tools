import 'package:test/test.dart';

import 'package:cli_tools/config.dart';

void main() {
  group('Given a DurationParser with normal default unit "s"', () {
    const durationParser = DurationParser();

    test('when calling parse with empty string then it throws FormatException.',
        () {
      expect(
        () => durationParser.parse(''),
        throwsA(isA<FormatException>()),
      );
    });

    test('when calling parse with "-" then it throws FormatException.', () {
      expect(
        () => durationParser.parse('-'),
        throwsA(isA<FormatException>()),
      );
    });

    test(
        'when calling parse with just an s unit then it throws FormatException.',
        () {
      expect(
        () => durationParser.parse('s'),
        throwsA(isA<FormatException>()),
      );
    });

    test(
        'when calling parse with 10 (implicit s unit) then it successfully returns a 10s Duration.',
        () {
      expect(
        durationParser.parse('10'),
        equals(const Duration(seconds: 10)),
      );
    });

    test(
        'when calling parse with 10s then it successfully returns a 10s Duration.',
        () {
      expect(
        durationParser.parse('10s'),
        equals(const Duration(seconds: 10)),
      );
    });

    test(
        'when calling parse with 10m then it successfully returns a 10m Duration.',
        () {
      expect(
        durationParser.parse('10m'),
        equals(const Duration(minutes: 10)),
      );
    });

    test(
        'when calling parse with 10h then it successfully returns a 10h Duration.',
        () {
      expect(
        durationParser.parse('10h'),
        equals(const Duration(hours: 10)),
      );
    });

    test(
        'when calling parse with 10d then it successfully returns a 10d Duration.',
        () {
      expect(
        durationParser.parse('10d'),
        equals(const Duration(days: 10)),
      );
    });

    test(
        'when calling parse with 10ms then it successfully returns a 10ms Duration.',
        () {
      expect(
        durationParser.parse('10ms'),
        equals(const Duration(milliseconds: 10)),
      );
    });

    test(
        'when calling parse with 10us then it successfully returns a 10us Duration.',
        () {
      expect(
        durationParser.parse('10us'),
        equals(const Duration(microseconds: 10)),
      );
    });

    test('when calling parse with 0 then it successfully returns a 0 Duration.',
        () {
      expect(
        durationParser.parse('0'),
        equals(Duration.zero),
      );
    });

    test(
        'when calling parse with 0s then it successfully returns a 0 Duration.',
        () {
      expect(
        durationParser.parse('0s'),
        equals(Duration.zero),
      );
    });

    test(
        'when calling parse with -10 then it successfully returns a -10s Duration.',
        () {
      expect(
        durationParser.parse('-10'),
        equals(const Duration(seconds: -10)),
      );
    });

    test(
        'when calling parse with -10s then it successfully returns a -10s Duration.',
        () {
      expect(
        durationParser.parse('-10s'),
        equals(const Duration(seconds: -10)),
      );
    });

    test(
        'when calling parse with 70s then it successfully returns a 1m10s Duration.',
        () {
      expect(
        durationParser.parse('70s'),
        equals(const Duration(minutes: 1, seconds: 10)),
      );
    });

    test(
        'when calling parse with 70m then it successfully returns a 1h10m Duration.',
        () {
      expect(
        durationParser.parse('70m'),
        equals(const Duration(hours: 1, minutes: 10)),
      );
    });

    test(
        'when calling parse with 70h then it successfully returns a 2d22h Duration.',
        () {
      expect(
        durationParser.parse('70h'),
        equals(const Duration(days: 2, hours: 22)),
      );
    });

    test(
        'when calling parse with a date string 2020-01-01T12:20:40 then it throws FormatException.',
        () {
      expect(
        () => durationParser.parse('2020-01-01T12:20:40'),
        throwsA(isA<FormatException>()),
      );
    });

    test('when calling format with 0 Duration then it returns the string "0s".',
        () {
      expect(
        durationParser.format(Duration.zero),
        equals('0s'),
      );
    });

    test(
        'when calling format with -10s Duration then it returns the string "-10s".',
        () {
      expect(
        durationParser.format(const Duration(seconds: -10)),
        equals('-10s'),
      );
    });

    test(
        'when calling format with 10m Duration then it returns the string "10m".',
        () {
      expect(durationParser.format(const Duration(minutes: 10)), equals('10m'));
    });

    test(
        'when calling format with 10h Duration then it returns the string "10h".',
        () {
      expect(durationParser.format(const Duration(hours: 10)), equals('10h'));
    });

    test(
        'when calling format with 10d Duration then it returns the string "10d".',
        () {
      expect(durationParser.format(const Duration(days: 10)), equals('10d'));
    });

    test(
        'when calling format with 10ms Duration then it returns the string "10ms".',
        () {
      expect(durationParser.format(const Duration(milliseconds: 10)),
          equals('10ms'));
    });

    test(
        'when calling format with 10us Duration then it returns the string "10us".',
        () {
      expect(durationParser.format(const Duration(microseconds: 10)),
          equals('10us'));
    });

    test(
        'when calling format with 99999d Duration then it returns the string "99999d".',
        () {
      expect(
        durationParser.format(const Duration(days: 99999)),
        equals('99999d'),
      );
    });

    test('when calling format with 0 Duration then it returns the string "0s".',
        () {
      expect(durationParser.format(Duration.zero), equals('0s'));
    });

    test(
        'when calling format with 1m10s Duration then it returns the string "1m10s".',
        () {
      expect(
        durationParser.format(const Duration(minutes: 1, seconds: 10)),
        equals('1m10s'),
      );
    });

    test(
        'when calling format with 1h10m Duration then it returns the string "1h10m".',
        () {
      expect(durationParser.format(const Duration(hours: 1, minutes: 10)),
          equals('1h10m'));
    });

    test(
        'when calling format with 2d22h Duration then it returns the string "2d22h".',
        () {
      expect(durationParser.format(const Duration(days: 2, hours: 22)),
          equals('2d22h'));
    });
  });

  group('Given a DurationParser with custom default unit "ms"', () {
    const durationParser = DurationParser(
      defaultUnit: DurationUnit.milliseconds,
    );

    test('when calling parse with empty string then it throws FormatException.',
        () {
      expect(
        () => durationParser.parse(''),
        throwsA(isA<FormatException>()),
      );
    });

    test('when calling parse with "-" then it throws FormatException.', () {
      expect(
        () => durationParser.parse('-'),
        throwsA(isA<FormatException>()),
      );
    });

    test(
        'when calling parse with just an ms unit then it throws FormatException.',
        () {
      expect(
        () => durationParser.parse('ms'),
        throwsA(isA<FormatException>()),
      );
    });

    test(
        'when calling parse with 10 (implicit ms unit) then it successfully returns a 10ms Duration.',
        () {
      expect(
        durationParser.parse('10'),
        equals(const Duration(milliseconds: 10)),
      );
    });

    test(
        'when calling parse with 10ms then it successfully returns a 10ms Duration.',
        () {
      expect(
        durationParser.parse('10ms'),
        equals(const Duration(milliseconds: 10)),
      );
    });

    test(
        'when calling parse with 10s then it successfully returns a 10s Duration.',
        () {
      expect(
        durationParser.parse('10s'),
        equals(const Duration(seconds: 10)),
      );
    });
  });
}
