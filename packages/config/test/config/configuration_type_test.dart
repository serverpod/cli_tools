import 'package:config/config.dart';
import 'package:test/test.dart';

enum AnimalEnum {
  cat,
  dog,
  mouse,
}

void main() async {
  group('Given a StringOption', () {
    const typedOpt = StringOption(argName: 'name');

    test('when passed an empty argument then it is parsed correctly', () async {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        args: ['--name', ''],
      );
      expect(config.optionalValue(typedOpt), equals(''));
    });
  });

  group('Given a StringOption that rejects empty strings', () {
    const typedOpt = StringOption(
      argName: 'name',
      envName: 'NAME',
      configKey: 'name',
      requireNonEmpty: true,
    );

    test(
      'when passed a non-empty value then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--name', 'alice'],
        );
        expect(config.optionalValue(typedOpt), equals('alice'));
      },
    );

    test('when passed an empty argument then it reports an error', () async {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        args: ['--name', ''],
      );

      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        equals('Invalid value for option "--name": Value must not be empty'),
      );
    });

    test('when passed an empty env var then it reports an error', () async {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        env: <String, String>{'NAME': ''},
      );

      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        equals('Invalid value for option "--name": Value must not be empty'),
      );
    });

    test(
      'when passed an empty config value then it reports an error',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          configBroker: _TestConfigBroker({'name': ''}),
        );

        expect(config.errors, hasLength(1));
        expect(
          config.errors.single,
          equals('Invalid value for option "--name": Value must not be empty'),
        );
      },
    );

    test(
      'when passed a whitespace value then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--name', ' '],
        );
        expect(config.optionalValue(typedOpt), equals(' '));
      },
    );

    test('when passed no value then it stays unset', () async {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        args: [],
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(typedOpt), isNull);
    });

    test('when the default is empty then it reports an error', () async {
      const option = StringOption(
        argName: 'name',
        defaultsTo: '',
        requireNonEmpty: true,
      );
      final config = Configuration.resolveNoExcept(
        options: [option],
        args: [],
      );

      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        equals('Invalid value for option "--name": Value must not be empty'),
      );
    });

    test('when the default is non-empty then it is used', () async {
      const option = StringOption(
        argName: 'name',
        defaultsTo: 'fallback',
        requireNonEmpty: true,
      );
      final config = Configuration.resolveNoExcept(
        options: [option],
        args: [],
      );
      expect(config.optionalValue(option), equals('fallback'));
    });
  });

  group('Given an EnumOption', () {
    const typedOpt = EnumOption(
      argName: 'animal',
      enumParser: EnumParser(AnimalEnum.values),
      mandatory: true,
    );

    test('when passed a valid value then it is parsed correctly', () async {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        args: ['--animal', 'cat'],
        env: <String, String>{},
      );
      expect(config.value(typedOpt), equals(AnimalEnum.cat));
    });

    test('when passed an invalid value then it reports an error', () async {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        args: ['--animal', 'unicorn'],
        env: <String, String>{},
      );

      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        equals(
          'Invalid value for option "--animal": "unicorn" is not in cat|dog|mouse',
        ),
      );
    });
  });

  group('Given an IntOption', () {
    const typedOpt = IntOption(
      argName: 'number',
      mandatory: true,
    );

    test(
      'when passed a valid positive value then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--number', '123'],
          env: <String, String>{},
        );
        expect(config.value(typedOpt), equals(123));
      },
    );

    test(
      'when passed a valid negative value then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--number', '-123'],
          env: <String, String>{},
        );
        expect(config.value(typedOpt), equals(-123));
      },
    );

    test('when passed a non-integer value then it reports an error', () async {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        args: ['--number', '0.45'],
        env: <String, String>{},
      );

      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        contains('Invalid value for option "--number" <integer>'),
      );
    });
    test('when passed a non-number value then it reports an error', () async {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        args: ['--number', 'unicorn'],
        env: <String, String>{},
      );

      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        contains('Invalid value for option "--number" <integer>'),
      );
    });
  });

  group('Given a ranged IntOption', () {
    const typedOpt = IntOption(
      argName: 'number',
      mandatory: true,
      min: 100,
      max: 200,
    );

    test('when passed a valid value then it is parsed correctly', () async {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        args: ['--number', '123'],
        env: <String, String>{},
      );
      expect(config.value(typedOpt), equals(123));
    });

    test(
      'when passed an integer value less than the range then it reports an error',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--number', '99'],
          env: <String, String>{},
        );

        expect(config.errors, hasLength(1));
        expect(
          config.errors.single,
          equals(
            'Invalid value for option "--number" <integer>: 99 is below the minimum (100)',
          ),
        );
      },
    );
    test(
      'when passed an integer value greater than the range then it reports an error',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--number', '201'],
          env: <String, String>{},
        );

        expect(config.errors, hasLength(1));
        expect(
          config.errors.single,
          equals(
            'Invalid value for option "--number" <integer>: 201 is above the maximum (200)',
          ),
        );
      },
    );
  });

  group('Given an IntOption with an allow-list', () {
    const typedOpt = IntOption(
      argName: 'number',
      envName: 'NUMBER',
      mandatory: true,
      allowedValues: [100, 200],
    );

    test('when passed a valid value then it is parsed correctly', () async {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        args: ['--number', '100'],
      );
      expect(config.value(typedOpt), equals(100));
    });

    test(
      'when passed an invalid integer value as arg then it reports an error',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--number', '99'],
        );

        expect(config.errors, hasLength(1));
        expect(
          config.errors.single,
          contains('`99` is not an allowed value for option "--number"'),
        );
      },
    );

    test(
      'when passed an invalid integer value as env var then it reports an error',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          env: <String, String>{'NUMBER': '99'},
        );

        expect(config.errors, hasLength(1));
        expect(
          config.errors.single,
          equals(
            'Invalid value for option "--number" <integer>: '
            '`99` is not an allowed value for option "--number"',
          ),
        );
      },
    );
  });

  group('Given a DoubleOption', () {
    const typedOpt = DoubleOption(
      argName: 'number',
      mandatory: true,
    );

    test(
      'when passed a fractional value then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--number', '1.5'],
          env: <String, String>{},
        );
        expect(config.value(typedOpt), equals(1.5));
      },
    );

    test(
      'when passed an integer value then it is parsed as a double',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--number', '2'],
          env: <String, String>{},
        );
        final value = config.value(typedOpt);
        expect(value, equals(2.0));
        expect(value, isA<double>());
      },
    );

    test(
      'when passed a valid negative value then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--number', '-1.25'],
          env: <String, String>{},
        );
        expect(config.value(typedOpt), equals(-1.25));
      },
    );

    test('when passed a non-number value then it reports an error', () async {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        args: ['--number', 'unicorn'],
        env: <String, String>{},
      );

      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        contains('Invalid value for option "--number" <number>'),
      );
    });
  });

  group('Given a ranged DoubleOption', () {
    const typedOpt = DoubleOption(
      argName: 'number',
      mandatory: true,
      min: 0.5,
      max: 1.5,
    );

    test('when passed a valid value then it is parsed correctly', () async {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        args: ['--number', '1.0'],
        env: <String, String>{},
      );
      expect(config.value(typedOpt), equals(1.0));
    });

    test(
      'when passed a value less than the range then it reports an error',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--number', '0.4'],
          env: <String, String>{},
        );

        expect(config.errors, hasLength(1));
        expect(
          config.errors.single,
          equals(
            'Invalid value for option "--number" <number>: '
            '0.4 is below the minimum (0.5)',
          ),
        );
      },
    );

    test(
      'when passed a value greater than the range then it reports an error',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--number', '1.6'],
          env: <String, String>{},
        );

        expect(config.errors, hasLength(1));
        expect(
          config.errors.single,
          equals(
            'Invalid value for option "--number" <number>: '
            '1.6 is above the maximum (1.5)',
          ),
        );
      },
    );
  });

  group('Given a DoubleOption read from configuration', () {
    const typedOpt = DoubleOption(
      argName: 'number',
      configKey: 'number',
      mandatory: true,
    );

    test('when the value is an integer then it resolves as a double', () {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        configBroker: _TestConfigBroker({'number': 2}),
      );

      final value = config.value(typedOpt);
      expect(value, equals(2.0));
      expect(value, isA<double>());
    });

    test('when the value is a double then it resolves as that double', () {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        configBroker: _TestConfigBroker({'number': 1.5}),
      );

      expect(config.value(typedOpt), equals(1.5));
    });

    test('when the value is a string integer then it resolves as a double', () {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        configBroker: _TestConfigBroker({'number': '2'}),
      );

      expect(config.value(typedOpt), equals(2.0));
    });

    test('when the value is not a number then it reports a type error', () {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        configBroker: _TestConfigBroker({'number': true}),
      );

      expect(config.errors, [
        'option "--number" value true is of type bool, not double.',
      ]);
    });
  });

  group('Given a DoubleOption with only a minimum', () {
    const typedOpt = DoubleOption(
      argName: 'number',
      mandatory: true,
      min: 0.0,
    );

    test('when passed negative zero then it is accepted', () {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        args: ['--number', '-0.0'],
      );

      expect(config.errors, isEmpty);
      expect(config.value(typedOpt), equals(0.0));
    });

    test('when passed positive zero then it is accepted', () {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        args: ['--number', '0.0'],
      );

      expect(config.value(typedOpt), equals(0.0));
    });

    test('when passed a negative value then it is below the minimum', () {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        args: ['--number', '-0.1'],
      );

      expect(config.errors, [
        'Invalid value for option "--number" <number>: '
            '-0.1 is below the minimum (0.0)',
      ]);
    });

    test('when passed NaN then it is rejected', () {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        args: ['--number', 'NaN'],
      );

      expect(config.errors, [
        'Invalid value for option "--number" <number>: '
            'NaN is not a valid number',
      ]);
    });

    test('when the default is NaN then it is rejected', () {
      const nanDefault = DoubleOption(
        argName: 'number',
        defaultsTo: double.nan,
        min: 0.0,
      );
      final config = Configuration.resolveNoExcept(
        options: [nanDefault],
        args: const [],
      );

      expect(config.errors, [
        'Invalid value for option "--number" <number>: '
            'NaN is not a valid number',
      ]);
    });
  });

  group('Given a DoubleOption with only a maximum of zero', () {
    const typedOpt = DoubleOption(
      argName: 'number',
      mandatory: true,
      max: 0.0,
    );

    test('when passed negative zero then it is accepted', () {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        args: ['--number', '-0.0'],
      );

      expect(config.errors, isEmpty);
      expect(config.value(typedOpt), equals(0.0));
    });
  });

  group('Given a DoubleOption with no numeric bounds', () {
    const typedOpt = DoubleOption(
      argName: 'number',
      mandatory: true,
    );

    test('when passed NaN then it is accepted', () {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        args: ['--number', 'NaN'],
      );

      expect(config.errors, isEmpty);
      expect(config.value(typedOpt).isNaN, isTrue);
    });
  });

  group('Given a ranged DurationOption', () {
    const typedOpt = DurationOption(
      argName: 'duration',
      mandatory: true,
      min: Duration.zero,
      max: Duration(days: 2),
    );

    test(
      'when passed a valid days value then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--duration', '1d'],
          env: <String, String>{},
        );
        expect(config.value(typedOpt), equals(const Duration(days: 1)));
      },
    );

    test(
      'when passed a valid hours value then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--duration', '2h'],
          env: <String, String>{},
        );
        expect(config.value(typedOpt), equals(const Duration(hours: 2)));
      },
    );

    test(
      'when passed a valid minutes value then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--duration', '3m'],
          env: <String, String>{},
        );
        expect(config.value(typedOpt), equals(const Duration(minutes: 3)));
      },
    );

    test(
      'when passed a valid seconds value then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--duration', '24s'],
          env: <String, String>{},
        );
        expect(config.value(typedOpt), equals(const Duration(seconds: 24)));
      },
    );

    test(
      'when passed a valid value with no unit then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--duration', '2'],
          env: <String, String>{},
        );
        expect(config.value(typedOpt), equals(const Duration(seconds: 2)));
      },
    );

    test(
      'when passed a value less than the range then it reports an error',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--duration', '-2s'],
          env: <String, String>{},
        );

        expect(config.errors, hasLength(1));
        expect(
          config.errors.single,
          equals(
            'Invalid value for option "--duration" <integer[us|ms|s|m|h|d]>: -2s is below the minimum (0s)',
          ),
        );
      },
    );

    test(
      'when passed a value greater than the range then it reports an error',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--duration', '20d'],
          env: <String, String>{},
        );

        expect(config.errors, hasLength(1));
        expect(
          config.errors.single,
          equals(
            'Invalid value for option "--duration" <integer[us|ms|s|m|h|d]>: 20d is above the maximum (2d)',
          ),
        );
      },
    );
  });

  group('Given a MultiOption of strings', () {
    const typedOpt = MultiOption(
      multiParser: MultiParser(StringParser()),
      argName: 'many',
      envName: 'SERVERPOD_MANY',
      configKey: 'many',
    );

    test('when passed no values then it is parsed correctly', () async {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        args: [],
      );
      expect(config.optionalValue(typedOpt), isNull);
    });

    test(
      'when passed a single arg value then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--many', '123'],
        );
        expect(config.optionalValue(typedOpt), equals(['123']));
      },
    );

    test(
      'when passed several arg values then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--many', '123', '--many', '456'],
        );
        expect(config.optionalValue(typedOpt), equals(['123', '456']));
      },
    );

    test(
      'when passed several comma-separated arg values then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--many', '123,456'],
        );
        expect(config.optionalValue(typedOpt), equals(['123', '456']));
      },
    );

    test('when passed empty env value then it is parsed correctly', () async {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        env: <String, String>{'SERVERPOD_MANY': ''},
      );
      expect(config.optionalValue(typedOpt), equals(['']));
    });

    test(
      'when passed several comma-separated env values then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          env: <String, String>{'SERVERPOD_MANY': '123,456'},
        );
        expect(config.optionalValue(typedOpt), equals(['123', '456']));
      },
    );

    test(
      'when passed null value from config source then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          configBroker: _TestConfigBroker({'many': null}),
        );
        expect(config.optionalValue(typedOpt), isNull);
      },
    );

    test(
      'when passed empty array of strings from config source then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          configBroker: _TestConfigBroker({'many': <String>[]}),
        );
        expect(config.optionalValue(typedOpt), equals([]));
      },
    );

    test(
      'when passed empty array of ints from config source then it reports a type error',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          configBroker: _TestConfigBroker({'many': <int>[]}),
        );
        expect(config.errors, hasLength(1));
        expect(
          config.errors.single,
          equals(
            'option "--many" value [] is of type List<int>, not List<String>.',
          ),
        );
      },
    );

    test(
      'when passed string array value from config source then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          configBroker: _TestConfigBroker({
            'many': ['123', '456'],
          }),
        );
        expect(config.optionalValue(typedOpt), equals(['123', '456']));
      },
    );

    test(
      'when passed plain string value from config source then it is parsed into a single-element array',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          configBroker: _TestConfigBroker({'many': 'plain-string'}),
        );
        expect(config.optionalValue(typedOpt), equals(['plain-string']));
      },
    );

    test(
      'when passed int array value from config source then it reports a type error',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          configBroker: _TestConfigBroker({
            'many': [123],
          }),
        );
        expect(config.errors, hasLength(1));
        expect(
          config.errors.single,
          equals(
            'option "--many" value [123] is of type List<int>, not List<String>.',
          ),
        );
      },
    );

    test(
      'when passed several comma-separated values in a plain string from config source then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          configBroker: _TestConfigBroker({'many': '123,456'}),
        );
        expect(config.optionalValue(typedOpt), equals(['123', '456']));
      },
    );
  });

  group('Given a MultiOption of integers without default value', () {
    const typedOpt = MultiOption(
      multiParser: MultiParser(IntParser()),
      argName: 'many',
      envName: 'SERVERPOD_MANY',
      configKey: 'many',
    );

    test('when passed no values then it is parsed correctly', () async {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        args: [],
      );
      expect(config.optionalValue(typedOpt), isNull);
    });

    test(
      'when passed a single arg value then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--many', '123'],
        );
        expect(config.optionalValue(typedOpt), equals([123]));
      },
    );

    test(
      'when passed several arg values then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--many', '123', '--many', '456'],
        );
        expect(config.optionalValue(typedOpt), equals([123, 456]));
      },
    );

    test(
      'when passed several comma-separated arg values then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--many', '123,456'],
        );
        expect(config.optionalValue(typedOpt), equals([123, 456]));
      },
    );

    test('when passed empty env value then it reports a parse error', () async {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        env: <String, String>{'SERVERPOD_MANY': ''},
      );
      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        startsWith(
          'Invalid value for option "--many": Invalid number (at character 1)',
        ),
      );
    });

    test(
      'when passed several comma-separated env values then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          env: <String, String>{'SERVERPOD_MANY': '123,456'},
        );
        expect(config.optionalValue(typedOpt), equals([123, 456]));
      },
    );

    test(
      'when passed null value from config source then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          configBroker: _TestConfigBroker({'many': null}),
        );
        expect(config.optionalValue(typedOpt), isNull);
      },
    );

    test(
      'when passed empty array of strings from config source then it reports a type error',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          configBroker: _TestConfigBroker({'many': <String>[]}),
        );
        expect(config.errors, hasLength(1));
        expect(
          config.errors.single,
          equals(
            'option "--many" value [] is of type List<String>, not List<int>.',
          ),
        );
      },
    );

    test(
      'when passed empty array of ints from config source then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          configBroker: _TestConfigBroker({'many': <int>[]}),
        );
        expect(config.optionalValue(typedOpt), equals([]));
      },
    );

    test(
      'when passed int array value from config source then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          configBroker: _TestConfigBroker({
            'many': [123, 456],
          }),
        );
        expect(config.optionalValue(typedOpt), equals([123, 456]));
      },
    );

    test(
      'when passed plain string value from config source then it reports a parse error',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          configBroker: _TestConfigBroker({'many': 'plain-string'}),
        );
        expect(config.errors, hasLength(1));
        expect(
          config.errors.single,
          startsWith(
            'Invalid value for option "--many": Invalid radix-10 number (at character 1)',
          ),
        );
      },
    );

    test(
      'when passed string array value from config source then it reports a type error',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          configBroker: _TestConfigBroker({
            'many': ['123'],
          }),
        );
        expect(config.errors, hasLength(1));
        expect(
          config.errors.single,
          equals(
            'option "--many" value [123] is of type List<String>, not List<int>.',
          ),
        );
      },
    );

    test(
      'when passed several comma-separated values in a plain string from config source then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          configBroker: _TestConfigBroker({'many': '123,456'}),
        );
        expect(config.optionalValue(typedOpt), equals([123, 456]));
      },
    );
  });

  group('Given a MultiOption of integers with default value', () {
    const typedOpt = MultiOption(
      multiParser: MultiParser(IntParser()),
      argName: 'many',
      envName: 'SERVERPOD_MANY',
      configKey: 'many',
      defaultsTo: [12, 45],
    );

    test('when passed no values then it produces the default value', () async {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        args: [],
      );
      expect(config.optionalValue(typedOpt), equals([12, 45]));
    });

    test(
      'when passed a single arg value then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--many', '123'],
        );
        expect(config.optionalValue(typedOpt), equals([123]));
      },
    );

    test(
      'when passed several arg values then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--many', '123', '--many', '456'],
        );
        expect(config.optionalValue(typedOpt), equals([123, 456]));
      },
    );

    test(
      'when passed several comma-separated arg values then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--many', '123,456'],
        );
        expect(config.optionalValue(typedOpt), equals([123, 456]));
      },
    );

    test('when passed empty env value then it reports a parse error', () async {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        env: <String, String>{'SERVERPOD_MANY': ''},
      );
      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        startsWith(
          'Invalid value for option "--many": Invalid number (at character 1)',
        ),
      );
    });

    test(
      'when passed several comma-separated env values then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          env: <String, String>{'SERVERPOD_MANY': '123,456'},
        );
        expect(config.optionalValue(typedOpt), equals([123, 456]));
      },
    );

    test(
      'when passed several arg and env values then args take precedence',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--many', '12', '--many', '45'],
          env: <String, String>{'SERVERPOD_MANY': '123,456'},
        );
        expect(config.optionalValue(typedOpt), equals([12, 45]));
      },
    );
  });

  group('Given a mandatory MultiOption of integers with alias', () {
    const typedOpt = MultiOption(
      multiParser: MultiParser(IntParser()),
      argName: 'many',
      argAliases: ['alias-many'],
      envName: 'SERVERPOD_MANY',
      configKey: 'many',
      mandatory: true,
    );

    test('when passed no values then it reports a parse error', () async {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        args: [],
      );
      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        equals('option "--many" is mandatory'),
      );
    });

    test(
      'when passed a single arg value then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--many', '123'],
        );
        expect(config.optionalValue(typedOpt), equals([123]));
      },
    );

    test(
      'when passed several arg values then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--many', '123', '--many', '456'],
        );
        expect(config.optionalValue(typedOpt), equals([123, 456]));
      },
    );

    test('when passed several arg values using both regular name and alias '
        'then it is parsed correctly', () async {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        args: ['--many', '123', '--alias-many', '456'],
      );
      expect(config.optionalValue(typedOpt), equals([123, 456]));
    });

    test(
      'when passed several comma-separated arg values then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--many', '123,456'],
        );
        expect(config.optionalValue(typedOpt), equals([123, 456]));
      },
    );

    test('when passed empty env value then it reports a parse error', () async {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        env: <String, String>{'SERVERPOD_MANY': ''},
      );
      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        startsWith(
          'Invalid value for option "--many": Invalid number (at character 1)',
        ),
      );
    });

    test(
      'when passed several comma-separated env values then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          env: <String, String>{'SERVERPOD_MANY': '123,456'},
        );
        expect(config.optionalValue(typedOpt), equals([123, 456]));
      },
    );
  });

  group('Given a MultiStringOption with an allow-list', () {
    const typedOpt = MultiStringOption(
      argName: 'many',
      envName: 'MANY',
      configKey: 'many',
      allowedValues: ['foo', 'bar', ''],
    );

    test('when passed no value then it is parsed correctly', () async {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        args: [],
      );
      expect(config.optionalValue(typedOpt), isNull);
    });

    test('when passed a valid value then it is parsed correctly', () async {
      final config = Configuration.resolveNoExcept(
        options: [typedOpt],
        args: ['--many', 'foo'],
      );
      expect(config.optionalValue(typedOpt), equals(['foo']));
    });

    test(
      'when passed a valid empty value then it is parsed correctly',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--many', ''],
        );
        expect(config.optionalValue(typedOpt), equals(['']));
      },
    );

    test(
      'when passed an invalid value as arg then it reports an error',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--many', 'wrong'],
        );

        expect(config.errors, hasLength(1));
        expect(
          config.errors.single,
          contains('`wrong` is not an allowed value for option "--many"'),
        );
        expect(
          () => config.optionalValue(typedOpt),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'when passed an invalid value as env var then it reports an error',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          env: <String, String>{'MANY': 'wrong'},
        );

        expect(config.errors, hasLength(1));
        expect(
          config.errors.single,
          equals(
            'Invalid value for option "--many": `wrong` is not an allowed value for option "--many"',
          ),
        );
        expect(
          () => config.optionalValue(typedOpt),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'when passed a valid and an invalid value then it reports an error',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [typedOpt],
          args: ['--many', 'foo', '--many', 'wrong'],
        );

        expect(config.errors, hasLength(1));
        expect(
          config.errors.single,
          contains('`wrong` is not an allowed value for option "--many"'),
        );
        expect(
          () => config.optionalValue(typedOpt),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  group(
    'Given a MultiOption whose element parser throws FormatException',
    () {
      const option = MultiOption<String>(
        multiParser: MultiParser(_RejectValueParser('android')),
        argName: 'platforms',
        envName: 'PLATFORMS',
        valueHelp: 'platform',
      );

      group('when the value is given as a named argument', () {
        late Configuration fromArg;
        late Configuration fromEnv;

        setUp(() {
          fromArg = Configuration.resolveNoExcept(
            options: [option],
            args: ['--platforms', 'android'],
          );
          fromEnv = Configuration.resolveNoExcept(
            options: [option],
            env: {'PLATFORMS': 'android'},
          );
        });

        test('then the error matches the environment variable error', () {
          expect(fromArg.errors, fromEnv.errors);
        });

        test('then the error does not mention FormatException', () {
          expect(
            fromArg.errors.single,
            isNot(contains('FormatException')),
          );
        });

        test('then the error quotes the parser message', () {
          expect(
            fromArg.errors.single,
            equals(
              'Invalid value for option "--platforms" <platform>: '
              'Invalid platform "android".',
            ),
          );
        });
      });

      group('when a later named occurrence is rejected', () {
        late Configuration fromArg;
        late Configuration fromEnv;

        setUp(() {
          fromArg = Configuration.resolveNoExcept(
            options: [option],
            args: ['--platforms', 'linux', '--platforms', 'android'],
          );
          fromEnv = Configuration.resolveNoExcept(
            options: [option],
            env: {'PLATFORMS': 'android'},
          );
        });

        test('then the error matches the environment variable error', () {
          expect(fromArg.errors, fromEnv.errors);
        });
      });
    },
  );

  group('Given a MultiOption with a string separator', () {
    const option = MultiOption<String>(
      multiParser: MultiParser(StringParser(), separator: '|'),
      argName: 'item',
    );

    test(
      'when passed repeated named arguments then each occurrence is kept',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [option],
          args: ['--item', 'a', '--item', 'b'],
        );
        expect(config.optionalValue(option), equals(['a', 'b']));
      },
    );

    test(
      'when passed a separated named argument then it splits on the separator',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [option],
          args: ['--item', 'a|b|c'],
        );
        expect(config.optionalValue(option), equals(['a', 'b', 'c']));
      },
    );

    test(
      'when passed repeated separated arguments then every element is kept',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [option],
          args: ['--item', 'a|b', '--item', 'c'],
        );
        expect(config.optionalValue(option), equals(['a', 'b', 'c']));
      },
    );
  });

  group('Given a MultiOption with no separator', () {
    const option = MultiOption<String>(
      multiParser: MultiParser(StringParser(), separator: null),
      argName: 'item',
    );

    test(
      'when passed a named argument containing commas then it stays one element',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [option],
          args: ['--item', 'a,b'],
        );
        expect(config.optionalValue(option), equals(['a,b']));
      },
    );

    test(
      'when passed repeated named arguments then each occurrence is one element',
      () async {
        final config = Configuration.resolveNoExcept(
          options: [option],
          args: ['--item', 'a,b', '--item', 'c'],
        );
        expect(config.optionalValue(option), equals(['a,b', 'c']));
      },
    );
  });
}

class _TestConfigBroker implements ConfigurationBroker {
  final Map<String, Object?> entries;

  _TestConfigBroker(this.entries);

  @override
  Object? valueOrNull(final String key, final Configuration cfg) {
    return entries[key];
  }
}

class _RejectValueParser extends ValueParser<String> {
  final String rejected;

  const _RejectValueParser(this.rejected);

  @override
  String parse(final String value) {
    if (value == rejected) {
      throw FormatException('Invalid platform "$value".');
    }
    return value;
  }
}
