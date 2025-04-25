import 'package:test/test.dart';

import 'package:cli_tools/config.dart';

enum AnimalEnum {
  cat,
  dog,
  mouse,
}

void main() async {
  group('Given an EnumOption', () {
    const typedOpt = EnumOption(
      argName: 'animal',
      enumParser: EnumParser(AnimalEnum.values),
      mandatory: true,
    );

    test('when passed a valid value then it is parsed correctly', () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--animal', 'cat'],
        env: <String, String>{},
      );
      expect(config.value(typedOpt), equals(AnimalEnum.cat));
    });

    test('when passed an invalid value then it reports an error', () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--animal', 'unicorn'],
        env: <String, String>{},
      );

      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        equals(
            'Invalid value for option `animal`: "unicorn" is not in cat|dog|mouse'),
      );
    });
  });

  group('Given an IntOption', () {
    const typedOpt = IntOption(
      argName: 'number',
      mandatory: true,
    );

    test('when passed a valid positive value then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--number', '123'],
        env: <String, String>{},
      );
      expect(config.value(typedOpt), equals(123));
    });

    test('when passed a valid negative value then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--number', '-123'],
        env: <String, String>{},
      );
      expect(config.value(typedOpt), equals(-123));
    });

    test('when passed a non-integer value then it reports an error', () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--number', '0.45'],
        env: <String, String>{},
      );

      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        contains('Invalid value for option `number` <integer>'),
      );
    });
    test('when passed a non-number value then it reports an error', () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--number', 'unicorn'],
        env: <String, String>{},
      );

      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        contains('Invalid value for option `number` <integer>'),
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
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--number', '123'],
        env: <String, String>{},
      );
      expect(config.value(typedOpt), equals(123));
    });

    test(
        'when passed an integer value less than the range then it reports an error',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--number', '99'],
        env: <String, String>{},
      );

      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        equals(
            'Invalid value for option `number` <integer>: 99 is below the minimum (100)'),
      );
    });
    test(
        'when passed an integer value greater than the range then it reports an error',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--number', '201'],
        env: <String, String>{},
      );

      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        equals(
            'Invalid value for option `number` <integer>: 201 is above the maximum (200)'),
      );
    });
  });

  group('Given an IntOption with an allow-list', () {
    const typedOpt = IntOption(
      argName: 'number',
      envName: 'NUMBER',
      mandatory: true,
      allowedValues: [100, 200],
    );

    test('when passed a valid value then it is parsed correctly', () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--number', '100'],
      );
      expect(config.value(typedOpt), equals(100));
    });

    test('when passed an invalid integer value as arg then it reports an error',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--number', '99'],
      );

      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        equals('"99" is not an allowed value for option "--number".'),
      );
    });

    test(
        'when passed an invalid integer value as env var then it reports an error',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        env: <String, String>{'NUMBER': '99'},
      );

      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        equals('Invalid value for option `number` <integer>: '
            '`99` is not an allowed value for option `number`'),
      );
    });
  });

  group('Given a ranged DurationOption', () {
    const typedOpt = DurationOption(
      argName: 'duration',
      mandatory: true,
      min: Duration.zero,
      max: Duration(days: 2),
    );

    test('when passed a valid days value then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--duration', '1d'],
        env: <String, String>{},
      );
      expect(config.value(typedOpt), equals(const Duration(days: 1)));
    });

    test('when passed a valid hours value then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--duration', '2h'],
        env: <String, String>{},
      );
      expect(config.value(typedOpt), equals(const Duration(hours: 2)));
    });

    test('when passed a valid minutes value then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--duration', '3m'],
        env: <String, String>{},
      );
      expect(config.value(typedOpt), equals(const Duration(minutes: 3)));
    });

    test('when passed a valid seconds value then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--duration', '24s'],
        env: <String, String>{},
      );
      expect(config.value(typedOpt), equals(const Duration(seconds: 24)));
    });

    test('when passed a valid value with no unit then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--duration', '2'],
        env: <String, String>{},
      );
      expect(config.value(typedOpt), equals(const Duration(seconds: 2)));
    });

    test('when passed a value less than the range then it reports an error',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--duration', '-2s'],
        env: <String, String>{},
      );

      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        equals(
            'Invalid value for option `duration` <integer[s|m|h|d]>: -2s is below the minimum (0s)'),
      );
    });

    test('when passed a value greater than the range then it reports an error',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--duration', '20d'],
        env: <String, String>{},
      );

      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        equals(
            'Invalid value for option `duration` <integer[s|m|h|d]>: 20d is above the maximum (2d)'),
      );
    });
  });

  group('Given a MultiOption of strings', () {
    const typedOpt = MultiOption(
      multiParser: MultiParser(elementParser: StringParser()),
      argName: 'many',
      envName: 'SERVERPOD_MANY',
      configKey: 'many',
    );

    test('when passed no values then it is parsed correctly', () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: [],
      );
      expect(config.optionalValue(typedOpt), isNull);
    });

    test('when passed a single arg value then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--many', '123'],
      );
      expect(config.optionalValue(typedOpt), equals(['123']));
    });

    test('when passed several arg values then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--many', '123', '--many', '456'],
      );
      expect(config.optionalValue(typedOpt), equals(['123', '456']));
    });

    test(
        'when passed several comma-separated arg values then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--many', '123,456'],
      );
      expect(config.optionalValue(typedOpt), equals(['123', '456']));
    });

    test('when passed empty env value then it is parsed correctly', () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        env: <String, String>{'SERVERPOD_MANY': ''},
      );
      expect(config.optionalValue(typedOpt), equals(['']));
    });

    test(
        'when passed several comma-separated env values then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        env: <String, String>{'SERVERPOD_MANY': '123,456'},
      );
      expect(config.optionalValue(typedOpt), equals(['123', '456']));
    });

    test(
        'when passed null value from config source then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        configBroker: _TestConfigBroker({'many': null}),
      );
      expect(config.optionalValue(typedOpt), isNull);
    });

    test(
        'when passed empty array of strings from config source then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        configBroker: _TestConfigBroker({'many': <String>[]}),
      );
      expect(config.optionalValue(typedOpt), equals([]));
    });

    test(
        'when passed empty array of ints from config source then it reports a type error',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        configBroker: _TestConfigBroker({'many': <int>[]}),
      );
      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        equals(
            'option `many` value [] is of type List<int>, not List<String>.'),
      );
    });

    test(
        'when passed string array value from config source then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        configBroker: _TestConfigBroker({
          'many': ['123', '456']
        }),
      );
      expect(config.optionalValue(typedOpt), equals(['123', '456']));
    });

    test(
        'when passed plain string value from config source then it is parsed into a single-element array',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        configBroker: _TestConfigBroker({'many': 'plain-string'}),
      );
      expect(config.optionalValue(typedOpt), equals(['plain-string']));
    });

    test(
        'when passed int array value from config source then it reports a type error',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        configBroker: _TestConfigBroker({
          'many': [123]
        }),
      );
      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        equals(
            'option `many` value [123] is of type List<int>, not List<String>.'),
      );
    });

    test(
        'when passed several comma-separated values in a plain string from config source then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        configBroker: _TestConfigBroker({'many': '123,456'}),
      );
      expect(config.optionalValue(typedOpt), equals(['123', '456']));
    });
  });

  group('Given a MultiOption of integers without default value', () {
    const typedOpt = MultiOption(
      multiParser: MultiParser(elementParser: IntParser()),
      argName: 'many',
      envName: 'SERVERPOD_MANY',
      configKey: 'many',
    );

    test('when passed no values then it is parsed correctly', () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: [],
      );
      expect(config.optionalValue(typedOpt), isNull);
    });

    test('when passed a single arg value then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--many', '123'],
      );
      expect(config.optionalValue(typedOpt), equals([123]));
    });

    test('when passed several arg values then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--many', '123', '--many', '456'],
      );
      expect(config.optionalValue(typedOpt), equals([123, 456]));
    });

    test(
        'when passed several comma-separated arg values then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--many', '123,456'],
      );
      expect(config.optionalValue(typedOpt), equals([123, 456]));
    });

    test('when passed empty env value then it reports a parse error', () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        env: <String, String>{'SERVERPOD_MANY': ''},
      );
      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        startsWith(
            'Invalid value for option `many`: Invalid number (at character 1)'),
      );
    });

    test(
        'when passed several comma-separated env values then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        env: <String, String>{'SERVERPOD_MANY': '123,456'},
      );
      expect(config.optionalValue(typedOpt), equals([123, 456]));
    });

    test(
        'when passed null value from config source then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        configBroker: _TestConfigBroker({'many': null}),
      );
      expect(config.optionalValue(typedOpt), isNull);
    });

    test(
        'when passed empty array of strings from config source then it reports a type error',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        configBroker: _TestConfigBroker({'many': <String>[]}),
      );
      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        equals(
            'option `many` value [] is of type List<String>, not List<int>.'),
      );
    });

    test(
        'when passed empty array of ints from config source then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        configBroker: _TestConfigBroker({'many': <int>[]}),
      );
      expect(config.optionalValue(typedOpt), equals([]));
    });

    test(
        'when passed int array value from config source then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        configBroker: _TestConfigBroker({
          'many': [123, 456]
        }),
      );
      expect(config.optionalValue(typedOpt), equals([123, 456]));
    });

    test(
        'when passed plain string value from config source then it reports a parse error',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        configBroker: _TestConfigBroker({'many': 'plain-string'}),
      );
      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        startsWith(
            'Invalid value for option `many`: Invalid radix-10 number (at character 1)'),
      );
    });

    test(
        'when passed string array value from config source then it reports a type error',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        configBroker: _TestConfigBroker({
          'many': ['123']
        }),
      );
      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        equals(
            'option `many` value [123] is of type List<String>, not List<int>.'),
      );
    });

    test(
        'when passed several comma-separated values in a plain string from config source then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        configBroker: _TestConfigBroker({'many': '123,456'}),
      );
      expect(config.optionalValue(typedOpt), equals([123, 456]));
    });
  });

  group('Given a MultiOption of integers with default value', () {
    const typedOpt = MultiOption(
      multiParser: MultiParser(elementParser: IntParser()),
      argName: 'many',
      envName: 'SERVERPOD_MANY',
      configKey: 'many',
      defaultsTo: [12, 45],
    );

    test('when passed no values then it produces the default value', () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: [],
      );
      expect(config.optionalValue(typedOpt), equals([12, 45]));
    });

    test('when passed a single arg value then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--many', '123'],
      );
      expect(config.optionalValue(typedOpt), equals([123]));
    });

    test('when passed several arg values then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--many', '123', '--many', '456'],
      );
      expect(config.optionalValue(typedOpt), equals([123, 456]));
    });

    test(
        'when passed several comma-separated arg values then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--many', '123,456'],
      );
      expect(config.optionalValue(typedOpt), equals([123, 456]));
    });

    test('when passed empty env value then it reports a parse error', () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        env: <String, String>{'SERVERPOD_MANY': ''},
      );
      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        startsWith(
            'Invalid value for option `many`: Invalid number (at character 1)'),
      );
    });

    test(
        'when passed several comma-separated env values then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        env: <String, String>{'SERVERPOD_MANY': '123,456'},
      );
      expect(config.optionalValue(typedOpt), equals([123, 456]));
    });

    test('when passed several arg and env values then args take precedence',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--many', '12', '--many', '45'],
        env: <String, String>{'SERVERPOD_MANY': '123,456'},
      );
      expect(config.optionalValue(typedOpt), equals([12, 45]));
    });
  });

  group('Given a mandatory MultiOption of integers with alias', () {
    const typedOpt = MultiOption(
      multiParser: MultiParser(elementParser: IntParser()),
      argName: 'many',
      argAliases: ['alias-many'],
      envName: 'SERVERPOD_MANY',
      configKey: 'many',
      mandatory: true,
    );

    test('when passed no values then it reports a parse error', () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: [],
      );
      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        equals('option `many` is mandatory'),
      );
    });

    test('when passed a single arg value then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--many', '123'],
      );
      expect(config.optionalValue(typedOpt), equals([123]));
    });

    test('when passed several arg values then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--many', '123', '--many', '456'],
      );
      expect(config.optionalValue(typedOpt), equals([123, 456]));
    });

    test(
        'when passed several arg values using both regular name and alias '
        'then it is parsed correctly', () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--many', '123', '--alias-many', '456'],
      );
      expect(config.optionalValue(typedOpt), equals([123, 456]));
    });

    test(
        'when passed several comma-separated arg values then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--many', '123,456'],
      );
      expect(config.optionalValue(typedOpt), equals([123, 456]));
    });

    test('when passed empty env value then it reports a parse error', () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        env: <String, String>{'SERVERPOD_MANY': ''},
      );
      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        startsWith(
            'Invalid value for option `many`: Invalid number (at character 1)'),
      );
    });

    test(
        'when passed several comma-separated env values then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        env: <String, String>{'SERVERPOD_MANY': '123,456'},
      );
      expect(config.optionalValue(typedOpt), equals([123, 456]));
    });
  });

  group('Given a MultiStringOption with an allow-list', () {
    const typedOpt = MultiStringOption(
      argName: 'many',
      envName: 'MANY',
      configKey: 'many',
      allowedValues: ['foo', 'bar', ''],
    );

    test('when passed no value then it is parsed correctly', () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: [],
      );
      expect(config.optionalValue(typedOpt), isNull);
    });

    test('when passed a valid value then it is parsed correctly', () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--many', 'foo'],
      );
      expect(config.optionalValue(typedOpt), equals(['foo']));
    });

    test('when passed a valid empty value then it is parsed correctly',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--many', ''],
      );
      expect(config.optionalValue(typedOpt), equals(['']));
    });

    test('when passed an invalid value as arg then it reports an error',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--many', 'wrong'],
      );

      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        equals('"wrong" is not an allowed value for option "--many".'),
      );
      expect(() => config.optionalValue(typedOpt), throwsA(isA<StateError>()));
    });

    test('when passed an invalid value as env var then it reports an error',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        env: <String, String>{'MANY': 'wrong'},
      );

      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        equals(
            'Invalid value for option `many`: `wrong` is not an allowed value for option `many`'),
      );
      expect(() => config.optionalValue(typedOpt), throwsA(isA<StateError>()));
    });

    test('when passed a valid and an invalid value then it reports an error',
        () async {
      final config = Configuration.resolve(
        options: [typedOpt],
        args: ['--many', 'foo', '--many', 'wrong'],
      );

      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        equals('"wrong" is not an allowed value for option "--many".'),
      );
      expect(() => config.optionalValue(typedOpt), throwsA(isA<StateError>()));
    });
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
