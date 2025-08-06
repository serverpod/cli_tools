import 'package:test/test.dart';

import 'package:cli_tools/config.dart';

void main() {
  group('Given a DateTimeParser', () {
    const dateTimeParser = DateTimeParser();

    test(
        'When calling parseDate() with empty string then it throws FormatException.',
        () {
      expect(
        () => dateTimeParser.parse(''),
        throwsA(isA<FormatException>()),
      );
    });

    test(
        'When calling parseDate() with 2020-01-01 then it successfully returns a DateTime.',
        () {
      expect(
        dateTimeParser.parse('2020-01-01'),
        equals(DateTime(2020, 1, 1)),
      );
    });

    test(
        'When calling parseDate() with 20200101 then it successfully returns a DateTime.',
        () {
      expect(
        dateTimeParser.parse('20200101'),
        equals(DateTime(2020, 1, 1)),
      );
    });

    test(
        'When calling parseDate() with 2020-01-01 12:20:40 then it successfully returns a DateTime.',
        () {
      expect(
        dateTimeParser.parse('2020-01-01 12:20:40'),
        equals(DateTime(2020, 1, 1, 12, 20, 40)),
      );
    });

    test(
        'When calling parseDate() with 2020-01-01T12:20:40Z then it successfully returns a DateTime.',
        () {
      expect(
        dateTimeParser.parse('2020-01-01T12:20:40Z'),
        equals(DateTime.utc(2020, 1, 1, 12, 20, 40)),
      );
    });

    test(
        'When calling parseDate() with 2020-01-01T12:20:40.001z then it successfully returns a DateTime.',
        () {
      expect(
        dateTimeParser.parse('2020-01-01T12:20:40.001z'),
        equals(DateTime.utc(2020, 1, 1, 12, 20, 40, 1)),
      );
    });

    test(
        'When calling parseDate() with 2020-01-01t12:20:40 then it successfully returns a DateTime.',
        () {
      expect(
        dateTimeParser.parse('2020-01-01t12:20:40'),
        equals(DateTime(2020, 1, 1, 12, 20, 40)),
      );
    });

    test(
        'When calling parseDate() with 2020-01-01-12:20:40 then it successfully returns a DateTime.',
        () {
      expect(
        dateTimeParser.parse('2020-01-01-12:20:40'),
        equals(DateTime(2020, 1, 1, 12, 20, 40)),
      );
    });

    test(
        'When calling parseDate() with 2020-01-01:12:20:40 then it successfully returns a DateTime.',
        () {
      expect(
        dateTimeParser.parse('2020-01-01:12:20:40'),
        equals(DateTime(2020, 1, 1, 12, 20, 40)),
      );
    });

    test(
        'When calling parseDate() with 2020-01-01_12:20:40 then it successfully returns a DateTime.',
        () {
      expect(
        dateTimeParser.parse('2020-01-01_12:20:40'),
        equals(DateTime(2020, 1, 1, 12, 20, 40)),
      );
    });

    test(
        'When calling parseDate() with 2020-01-01/12:20:40 then it successfully returns a DateTime.',
        () {
      expect(
        dateTimeParser.parse('2020-01-01/12:20:40'),
        equals(DateTime(2020, 1, 1, 12, 20, 40)),
      );
    });

    test(
        'When calling parseDate() with 2020-01-01x12:20:40 then it throws FormatException.',
        () {
      expect(
        () => dateTimeParser.parse('2020-01-01x12:20:40'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
