import 'package:config/config.dart';
import 'package:test/test.dart';

void main() {
  group('Given a DateTimeParser', () {
    const parser = DateTimeParser();

    group('when parsing a valid value', () {
      final cases = <String, DateTime>{
        '2020-01-01': DateTime(2020),
        '20200101': DateTime(2020),
        '+2020-01-01': DateTime(2020),
        '0000-02-29': DateTime(0, 2, 29),
        '-0004-02-29': DateTime(-4, 2, 29),
        '2024-02-29': DateTime(2024, 2, 29),
        '2000-02-29': DateTime(2000, 2, 29),
        '2020-01-01 12:20:40': DateTime(2020, 1, 1, 12, 20, 40),
        '2020-01-01T12:20:40Z': DateTime.utc(2020, 1, 1, 12, 20, 40),
        '2020-01-01T12:20:40z': DateTime.utc(2020, 1, 1, 12, 20, 40),
        '2020-01-01T12:20:40.001z': DateTime.utc(2020, 1, 1, 12, 20, 40, 1),
        '2020-01-01T12:20:40.1': DateTime(2020, 1, 1, 12, 20, 40, 100),
        '2020-01-01T12:20:40,123': DateTime(2020, 1, 1, 12, 20, 40, 123),
        '2020-01-01T12:20:40.123456': DateTime(
          2020,
          1,
          1,
          12,
          20,
          40,
          123,
          456,
        ),
        '2020-01-01t12:20:40': DateTime(2020, 1, 1, 12, 20, 40),
        '2020-01-01-12:20:40': DateTime(2020, 1, 1, 12, 20, 40),
        '2020-01-01:12:20:40': DateTime(2020, 1, 1, 12, 20, 40),
        '2020-01-01_12:20:40': DateTime(2020, 1, 1, 12, 20, 40),
        '2020-01-01/12:20:40': DateTime(2020, 1, 1, 12, 20, 40),
        '2020-01-01-05:00': DateTime(2020, 1, 1, 5),
        '2020-01-01T12': DateTime(2020, 1, 1, 12),
        '2020-01-01T12:20': DateTime(2020, 1, 1, 12, 20),
        '20200101T122040Z': DateTime.utc(2020, 1, 1, 12, 20, 40),
        '2020-01-01 12:20:40 Z': DateTime.utc(2020, 1, 1, 12, 20, 40),
        '9999-12-31': DateTime(9999, 12, 31),
        '2026-08-01T12:00:00+02:00': DateTime.utc(2026, 8, 1, 10),
        '2026-08-01T12:00:00+02': DateTime.utc(2026, 8, 1, 10),
        '2026-08-01T12:00:00+0200': DateTime.utc(2026, 8, 1, 10),
        '2026-08-01T12:00:00-05:00': DateTime.utc(2026, 8, 1, 17),
        '2026-08-01T00:30:00+02:00': DateTime.utc(2026, 7, 31, 22, 30),
        '2020-01-01T12:20:40+05:30': DateTime.utc(2020, 1, 1, 6, 50, 40),
      };

      for (final entry in cases.entries) {
        test('then ${entry.key} is that DateTime', () {
          expect(parser.parse(entry.key), entry.value);
        });
      }

      test('then a value without an offset is local', () {
        final parsed = parser.parse('2026-08-01');
        expect(parsed, DateTime(2026, 8, 1));
        expect(parsed.isUtc, isFalse);
      });

      test('then Z is UTC', () {
        final parsed = parser.parse('2026-08-01T00:00:00Z');
        expect(parsed, DateTime.utc(2026, 8, 1));
        expect(parsed.isUtc, isTrue);
      });
    });

    group('when a component is out of range', () {
      final cases = <String, String>{
        '2026-02-31': 'day must be between 1 and 28',
        '2026-02-29': 'day must be between 1 and 28',
        '2026-02-30': 'day must be between 1 and 28',
        '2100-02-29': 'day must be between 1 and 28',
        '1900-02-29': 'day must be between 1 and 28',
        '-0003-02-29': 'day must be between 1 and 28',
        '2026-02-31T12:00:00Z': 'day must be between 1 and 28',
        '2026-13-01': 'month must be between 1 and 12',
        '2026-00-01': 'month must be between 1 and 12',
        '2026-01-00': 'day must be between 1 and 31',
        '2026-01-32': 'day must be between 1 and 31',
        '2026-04-31': 'day must be between 1 and 30',
        '2026-11-31': 'day must be between 1 and 30',
        '2026-01-01T24:00:00': 'hour must be between 0 and 23',
        '2026-01-01T24:00:00Z': 'hour must be between 0 and 23',
        '2026-01-01T25:00:00': 'hour must be between 0 and 23',
        '2026-01-01T00:60:00': 'minute must be between 0 and 59',
        '2026-01-01T00:00:60': 'second must be between 0 and 59',
        '2026-01-01T23:59:60Z': 'second must be between 0 and 59',
        '2026-01-01T12:00:00.0000001':
            'fractional seconds must have at most 6 digits',
        '2026-01-01T12:00:00.1234567':
            'fractional seconds must have at most 6 digits',
        '2026-01-01T12:00:00+24:00': 'time-zone hour must be between 0 and 23',
        '2026-01-01T12:00:00+05:60':
            'time-zone minute must be between 0 and 59',
      };

      for (final entry in cases.entries) {
        test('then ${entry.key} is rejected', () {
          expect(
            () => parser.parse(entry.key),
            throwsA(
              isA<FormatException>().having(
                (final e) => e.message,
                'message',
                'Invalid date-time "${entry.key}": ${entry.value}',
              ),
            ),
          );
        });
      }
    });

    group('when the text is not a date-time', () {
      for (final input in [
        '',
        '2020-01-01x12:20:40',
        '2020-01-01Z',
        ' 2020-01-01',
        '2020-01-01 ',
        '2020-1-1',
        '2020-01-01T12:20:40+5:00',
        '2020-01-01T12:20:40+00:00:00',
        '2020-01-01T',
        '10000-01-01',
        '10000-01-01t12:30:00',
        '999999-01-01',
      ]) {
        test('then $input is rejected', () {
          expect(
            () => parser.parse(input),
            throwsA(
              isA<FormatException>().having(
                (final e) => e.message,
                'message',
                'Invalid date-time "$input"',
              ),
            ),
          );
        });
      }
    });

    group('when formatting', () {
      test('then an offset value is written as UTC and round-trips', () {
        final parsed = parser.parse('2026-08-01T00:30:00+02:00');
        expect(parser.format(parsed), '2026-07-31T22:30:00Z');
        expect(parser.parse(parser.format(parsed)), parsed);
      });

      test('then fractional seconds round-trip without extra zeros', () {
        expect(
          parser.format(parser.parse('2020-01-01T12:20:40.001Z')),
          '2020-01-01T12:20:40.001Z',
        );
        expect(
          parser.format(parser.parse('2020-01-01T12:20:40.1Z')),
          '2020-01-01T12:20:40.1Z',
        );
        expect(
          parser.format(parser.parse('2020-01-01T12:20:40.000001Z')),
          '2020-01-01T12:20:40.000001Z',
        );
      });

      test('then a local value is written without Z and round-trips', () {
        final local = DateTime(2026, 8, 1, 12);
        expect(parser.format(local), '2026-08-01T12:00:00');
        expect(parser.parse(parser.format(local)), local);
      });

      test('then a UTC value is written with Z and round-trips', () {
        final utc = DateTime.utc(2026, 8, 1, 12);
        expect(parser.format(utc), '2026-08-01T12:00:00Z');
        expect(parser.parse(parser.format(utc)), utc);
      });
    });
  });

  group('Given a date-only DateTimeParser', () {
    const parser = DateTimeParser(dateOnly: true);

    test('when parsing YYYY-MM-DD then it is local midnight', () {
      expect(parser.parse('2026-08-01'), DateTime(2026, 8, 1));
    });

    test('when parsing a compact date then it is local midnight', () {
      expect(parser.parse('20260801'), DateTime(2026, 8, 1));
    });

    test('when parsing an impossible date then it is rejected', () {
      expect(
        () => parser.parse('2026-02-31'),
        throwsA(
          isA<FormatException>().having(
            (final e) => e.message,
            'message',
            'Invalid date "2026-02-31": day must be between 1 and 28',
          ),
        ),
      );
    });

    test('when parsing a timestamp then a time is not allowed', () {
      expect(
        () => parser.parse('2026-08-01T00:00:00Z'),
        throwsA(
          isA<FormatException>().having(
            (final e) => e.message,
            'message',
            'Invalid date "2026-08-01T00:00:00Z": a time is not allowed',
          ),
        ),
      );
    });

    test('when parsing a date with Z then it is rejected', () {
      expect(
        () => parser.parse('2026-08-01Z'),
        throwsA(
          isA<FormatException>().having(
            (final e) => e.message,
            'message',
            'Invalid date "2026-08-01Z"',
          ),
        ),
      );
    });

    test('when formatting then only the calendar date is shown', () {
      expect(parser.format(DateTime.utc(2026, 8, 1, 15)), '2026-08-01');
    });
  });

  group('Given a DateTimeOption', () {
    const timestamp = DateTimeOption(argName: 'before', mandatory: true);
    const calendar = DateTimeOption(
      argName: 'on',
      dateOnly: true,
      mandatory: true,
    );

    test('then the value help describes a timestamp', () {
      expect(timestamp.valueHelp, 'YYYY-MM-DDTHH:MM:SSZ');
      expect(timestamp.dateOnly, isFalse);
    });

    test('then a date-only option describes a calendar date', () {
      expect(calendar.valueHelp, 'YYYY-MM-DD');
      expect(calendar.dateOnly, isTrue);
      expect(
        calendar.valueParser,
        isA<DateTimeParser>().having(
          (final parser) => parser.dateOnly,
          'dateOnly',
          isTrue,
        ),
      );
    });

    test('then an explicit value help is kept', () {
      expect(
        const DateTimeOption(valueHelp: 'when').valueHelp,
        'when',
      );
      expect(
        const DateTimeOption(dateOnly: true, valueHelp: 'when').valueHelp,
        'when',
      );
    });

    test(
      'when passed a calendar date then it resolves to local midnight',
      () {
        final config = Configuration.resolveNoExcept(
          options: [timestamp],
          args: ['--before', '2026-08-01'],
        );
        expect(config.errors, isEmpty);
        expect(config.value(timestamp), DateTime(2026, 8, 1));
      },
    );

    test('when passed an impossible date then the error names the range', () {
      final config = Configuration.resolveNoExcept(
        options: [timestamp],
        args: ['--before', '2026-02-31'],
      );
      expect(config.errors, [
        'Invalid value for option `before` <YYYY-MM-DDTHH:MM:SSZ>: '
            'Invalid date-time "2026-02-31": day must be between 1 and 28',
      ]);
    });

    test(
      'when a date-only option is passed a timestamp then it is rejected',
      () {
        final config = Configuration.resolveNoExcept(
          options: [calendar],
          args: ['--on', '2026-08-01T00:00:00Z'],
        );
        expect(config.errors, [
          'Invalid value for option `on` <YYYY-MM-DD>: '
              'Invalid date "2026-08-01T00:00:00Z": a time is not allowed',
        ]);
      },
    );
  });

  group('Given a DateTimeOption with a maximum instant', () {
    final option = DateTimeOption(
      argName: 'before',
      mandatory: true,
      max: DateTime.utc(2026, 8, 1),
    );

    test('when the value equals the maximum then it is accepted', () {
      final config = Configuration.resolveNoExcept(
        options: [option],
        args: ['--before', '2026-08-01T00:00:00Z'],
      );
      expect(config.value(option), DateTime.utc(2026, 8, 1));
    });

    test('when the value is later than the maximum then it is rejected', () {
      final config = Configuration.resolveNoExcept(
        options: [option],
        args: ['--before', '2026-08-02'],
      );
      expect(config.errors, [
        'Invalid value for option `before` <YYYY-MM-DDTHH:MM:SSZ>: '
            '2026-08-02T00:00:00 is above the maximum '
            '(2026-08-01T00:00:00Z)',
      ]);
    });
  });
}
