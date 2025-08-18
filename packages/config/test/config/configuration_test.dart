import 'package:args/args.dart';
import 'package:config/config.dart';
import 'package:test/test.dart';

void main() async {
  group('Given invalid configuration abbrevation without full name', () {
    const projectIdOpt = StringOption(
      argAbbrev: 'p',
    );
    final parser = ArgParser();

    test('when preparing for parsing then throws exception', () async {
      expect(
        () => [projectIdOpt].prepareForParsing(parser),
        throwsA(isA<OptionDefinitionError>().having(
          (final e) => e.message,
          'message',
          "An argument option can't have an abbreviation but not a full name",
        )),
      );
    });
  });

  group('Given invalid configuration mandatory with default value', () {
    const projectIdOpt = StringOption(
      mandatory: true,
      defaultsTo: 'default',
    );
    final parser = ArgParser();

    test('when preparing for parsing then throws exception', () async {
      expect(
        () => [projectIdOpt].prepareForParsing(parser),
        throwsA(isA<OptionDefinitionError>().having(
          (final e) => e.message,
          'message',
          "Mandatory options can't have default values",
        )),
      );
    });
  });

  group(
      'Given invalid configuration mandatory with default value from function',
      () {
    const projectIdOpt = StringOption(
      mandatory: true,
      fromDefault: _defaultValueFunction,
    );

    final parser = ArgParser();

    test('when preparing for parsing then throws exception', () async {
      expect(
        () => [projectIdOpt].prepareForParsing(parser),
        throwsA(isA<OptionDefinitionError>().having(
          (final e) => e.message,
          'message',
          "Mandatory options can't have default values",
        )),
      );
    });
  });

  group('Given a configuration option definition', () {
    const projectIdOpt = StringOption(
      argName: 'project',
    );

    group('added to the arg parser', () {
      final parser = ArgParser();
      [projectIdOpt].prepareForParsing(parser);

      test('then it is listed as an option there', () async {
        expect(parser.options, contains('project'));
      });

      test('when present on the command line, then it is successfully parsed',
          () async {
        final results = parser.parse(['--project', '123']);
        expect(results.option('project'), '123');
      });

      test('when present on the command line, then it is marked as parsed',
          () async {
        final results = parser.parse(['--project', '123']);
        expect(results.wasParsed('project'), isTrue);
      });

      test(
          'when not present on the command line, then it is marked as not parsed',
          () async {
        final results = parser.parse(['123']);
        expect(results.wasParsed('project'), isFalse);
      });

      test('when misspelled on the command line, then it fails to parse',
          () async {
        expect(() => parser.parse(['--projectid', '123']),
            throwsA(isA<ArgParserException>()));
      });

      test('when present twice on the command line, the value is the last one',
          () async {
        final results = parser.parse(['--project', '123', '--project', '456']);
        expect(results.option('project'), '456');
      });
    });
  });

  group('Given a configuration option defined for all sources', () {
    const projectIdOpt = StringOption(
      argName: 'project',
      envName: 'PROJECT_ID',
      configKey: 'config:/projectId',
      fromCustom: _customValueFunction,
      fromDefault: _defaultValueFunction,
      defaultsTo: 'constDefaultValue',
    );

    test(
        'when getting the usage from a list with the option '
        'then the usage is returned', () async {
      final options = [projectIdOpt];
      expect(
        options.usage,
        equals('--project    (defaults to "defaultValueFunction")'),
      );
    });

    test(
        'when getting the usage from a resolved configuration '
        'then the usage is returned', () async {
      final config = Configuration.resolveNoExcept(
        options: [projectIdOpt],
      );
      expect(
        config.usage,
        equals('--project    (defaults to "defaultValueFunction")'),
      );
    });

    test('then command line argument has first precedence', () async {
      final args = ['--project', '123'];
      final envVars = {'PROJECT_ID': '456'};
      final config = Configuration.resolveNoExcept(
        options: [projectIdOpt],
        args: args,
        env: envVars,
        configBroker:
            _TestConfigBroker({'config:/projectId': 'configSourceValue'}),
      );
      expect(config.value(projectIdOpt), equals('123'));
    });

    test('then env variable has second precedence', () async {
      final args = <String>[];
      final envVars = {'PROJECT_ID': '456'};
      final config = Configuration.resolveNoExcept(
        options: [projectIdOpt],
        args: args,
        env: envVars,
        configBroker:
            _TestConfigBroker({'config:/projectId': 'configSourceValue'}),
      );
      expect(config.value(projectIdOpt), equals('456'));
    });

    test('then configKey has third precedence', () async {
      final args = <String>[];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: [projectIdOpt],
        args: args,
        env: envVars,
        configBroker:
            _TestConfigBroker({'config:/projectId': 'configSourceValue'}),
      );
      expect(config.value(projectIdOpt), equals('configSourceValue'));
    });

    test('then fromCustom function has fourth precedence', () async {
      final args = <String>[];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: [projectIdOpt],
        args: args,
        env: envVars,
        configBroker: _TestConfigBroker({}),
      );
      expect(config.value(projectIdOpt), equals('customValueFunction'));
    });

    test('when provided twice via args then the last value is used', () async {
      // Note: This is the behavior of ArgParser.
      // It may be considered to make this a usage error instead.
      final args = ['--project', '123', '--project', '456'];
      final config = Configuration.resolveNoExcept(
        options: [projectIdOpt],
        args: args,
      );
      expect(config.value(projectIdOpt), equals('456'));
    });
  });

  group('Given a configuration option with a defaultsTo value', () {
    const projectIdOpt = StringOption(
      argName: 'project',
      envName: 'PROJECT_ID',
      configKey: 'config:/projectId',
      fromCustom: _customNullFunction,
      defaultsTo: 'constDefaultValue',
    );

    test('then command line argument has first precedence', () async {
      final args = ['--project', '123'];
      final envVars = {'PROJECT_ID': '456'};
      final config = Configuration.resolveNoExcept(
        options: [projectIdOpt],
        args: args,
        env: envVars,
        configBroker:
            _TestConfigBroker({'config:/projectId': 'configSourceValue'}),
      );
      expect(config.value(projectIdOpt), equals('123'));
    });

    test('then env variable has second precedence', () async {
      final args = <String>[];
      final envVars = {'PROJECT_ID': '456'};
      final config = Configuration.resolveNoExcept(
        options: [projectIdOpt],
        args: args,
        env: envVars,
        configBroker:
            _TestConfigBroker({'config:/projectId': 'configSourceValue'}),
      );
      expect(config.value(projectIdOpt), equals('456'));
    });

    test('then configKey has third precedence', () async {
      final args = <String>[];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: [projectIdOpt],
        args: args,
        env: envVars,
        configBroker:
            _TestConfigBroker({'config:/projectId': 'configSourceValue'}),
      );
      expect(config.value(projectIdOpt), equals('configSourceValue'));
    });

    test('then defaultsTo value has last precedence', () async {
      final args = <String>[];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: [projectIdOpt],
        args: args,
        env: envVars,
        configBroker: _TestConfigBroker({}),
      );
      expect(config.value(projectIdOpt), equals('constDefaultValue'));
    });
  });

  group('Given a configuration flag option', () {
    const verboseFlag = FlagOption(
      argName: 'verbose',
      envName: 'VERBOSE',
      defaultsTo: false,
    );

    test('then command line argument has first precedence', () async {
      final args = ['--verbose'];
      final envVars = {'VERBOSE': 'false'};
      final config = Configuration.resolveNoExcept(
        options: [verboseFlag],
        args: args,
        env: envVars,
      );
      expect(config.value(verboseFlag), isTrue);
    });

    test('then env variable has second precedence', () async {
      final args = <String>[];
      final envVars = {'VERBOSE': 'true'};
      final config = Configuration.resolveNoExcept(
        options: [verboseFlag],
        args: args,
        env: envVars,
      );
      expect(config.value(verboseFlag), isTrue);
    });
  });

  group('Given a configuration flag option', () {
    const verboseFlag = FlagOption(
      argName: 'verbose',
      envName: 'VERBOSE',
      defaultsTo: true,
    );

    test('then defaultsTo value has last precedence', () async {
      final args = <String>[];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: [verboseFlag],
        args: args,
        env: envVars,
      );
      expect(config.errors, isEmpty);
      expect(config.value(verboseFlag), isTrue);
    });
  });

  group('Given an optional configuration option', () {
    const projectIdOpt = StringOption(
      argName: 'project',
      envName: 'PROJECT_ID',
    );

    test('when provided as argument then value() still throws StateError',
        () async {
      final args = ['--project', '123'];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: [projectIdOpt],
        args: args,
        env: envVars,
      );
      expect(() => config.value(projectIdOpt), throwsA(isA<StateError>()));
    });

    test('when provided as env variable then value() still throws StateError',
        () async {
      final args = <String>[];
      final envVars = {'PROJECT_ID': '456'};
      final config = Configuration.resolveNoExcept(
        options: [projectIdOpt],
        args: args,
        env: envVars,
      );
      expect(() => config.value(projectIdOpt), throwsA(isA<StateError>()));
    });

    test('when not provided then calling value() throws StateError', () async {
      final args = <String>[];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: [projectIdOpt],
        args: args,
        env: envVars,
      );
      expect(() => config.value(projectIdOpt), throwsA(isA<StateError>()));
    });

    test('when provided as argument then parsing succeeds', () async {
      final args = ['--project', '123'];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: [projectIdOpt],
        args: args,
        env: envVars,
      );
      expect(config.optionalValue(projectIdOpt), equals('123'));
    });

    test('when provided as env variable then parsing succeeds', () async {
      final args = <String>[];
      final envVars = {'PROJECT_ID': '456'};
      final config = Configuration.resolveNoExcept(
        options: [projectIdOpt],
        args: args,
        env: envVars,
      );
      expect(config.optionalValue(projectIdOpt), equals('456'));
    });

    test('when not provided then parsing succeeds and results in null',
        () async {
      final args = <String>[];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: [projectIdOpt],
        args: args,
        env: envVars,
      );
      expect(config.optionalValue(projectIdOpt), isNull);
    });
  });

  group('Given a mandatory configuration option', () {
    const projectIdOpt = StringOption(
      argName: 'project',
      envName: 'PROJECT_ID',
      mandatory: true,
    );

    test(
        'when not provided and calling resolveNoExcept '
        'then it returns normally with a registered error message', () async {
      final args = <String>[];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: [projectIdOpt],
        args: args,
        env: envVars,
      );
      expect(config.errors, hasLength(1));
      expect(config.errors.first, 'option `project` is mandatory');
      expect(
        () => config.value(projectIdOpt),
        throwsA(isA<StateError>().having(
          (final e) => e.message,
          'message',
          contains(
              'No value available for option `project` due to previous errors'),
        )),
      );
    });

    test(
        'when not provided and calling resolve '
        'then it throws a UsageException', () async {
      final args = <String>[];
      final envVars = <String, String>{};
      expect(
          () => Configuration.resolve(
                options: [projectIdOpt],
                args: args,
                env: envVars,
              ),
          throwsA(isA<UsageException>()
              .having(
                (final e) => e.message,
                'message',
                contains('Option `project` is mandatory.'),
              )
              .having(
                (final e) => e.usage,
                'usage',
                contains('--project (mandatory)'),
              )));
    });
  });

  group('Given a mandatory configuration option', () {
    const projectIdOpt = StringOption(
      argName: 'project',
      envName: 'PROJECT_ID',
      mandatory: true,
    );

    test('when provided as argument then parsing succeeds', () async {
      final args = ['--project', '123'];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: [projectIdOpt],
        args: args,
        env: envVars,
      );
      expect(config.errors, isEmpty);
      expect(config.value(projectIdOpt), equals('123'));
    });

    test('when provided as env variable then parsing succeeds', () async {
      final args = <String>[];
      final envVars = {'PROJECT_ID': '456'};
      final config = Configuration.resolveNoExcept(
        options: [projectIdOpt],
        args: args,
        env: envVars,
      );
      expect(config.errors, isEmpty);
      expect(config.value(projectIdOpt), equals('456'));
    });

    test('when not provided then parsing has error', () async {
      final args = <String>[];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: [projectIdOpt],
        args: args,
        env: envVars,
      );
      expect(config.errors, hasLength(1));
      expect(config.errors.first, 'option `project` is mandatory');
      expect(
        () => config.value(projectIdOpt),
        throwsA(isA<StateError>().having(
          (final e) => e.message,
          'message',
          contains(
              'No value available for option `project` due to previous errors'),
        )),
      );
    });
  });

  group('Given a mandatory env-only configuration option', () {
    const projectIdOpt = StringOption(
      envName: 'PROJECT_ID',
      mandatory: true,
    );

    test('when provided as argument then parsing fails', () async {
      final parser = ArgParser();
      [projectIdOpt].prepareForParsing(parser);
      expect(() => parser.parse(['--project', '123']),
          throwsA(isA<ArgParserException>()));
    });

    test('when provided as env variable then parsing succeeds', () async {
      final args = <String>[];
      final envVars = {'PROJECT_ID': '456'};
      final config = Configuration.resolveNoExcept(
        options: [projectIdOpt],
        args: args,
        env: envVars,
      );
      expect(config.errors, isEmpty);
      expect(config.value(projectIdOpt), equals('456'));
    });

    test('when not provided then parsing has error', () async {
      final args = <String>[];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: [projectIdOpt],
        args: args,
        env: envVars,
      );
      expect(config.errors, hasLength(1));
      expect(config.errors.first,
          'environment variable `PROJECT_ID` is mandatory');
      expect(
        () => config.value(projectIdOpt),
        throwsA(isA<StateError>().having(
          (final e) => e.message,
          'message',
          contains(
              'No value available for environment variable `PROJECT_ID` due to previous errors'),
        )),
      );
    });
  });

  group('Given invalid combinations of options', () {
    const argNameOpt = StringOption(
      argName: 'arg-name',
    );
    const envNameOpt = StringOption(
      envName: 'env-name',
    );
    const duplicateOpt = StringOption(
      argName: 'arg-name',
      envName: 'env-name',
      argPos: 0,
    );
    const argPosOpt = StringOption(
      argPos: 0,
    );
    const argPos2Opt = StringOption(
      argPos: 2,
    );

    test(
        'when duplicate arg names specified then InvalidOptionConfigurationException is thrown',
        () async {
      final parser = ArgParser();
      expect(() => [argNameOpt, duplicateOpt].prepareForParsing(parser),
          throwsA(isA<OptionDefinitionError>()));
    });

    test(
        'when duplicate env names specified then InvalidOptionConfigurationException is thrown',
        () async {
      final parser = ArgParser();
      expect(() => [envNameOpt, duplicateOpt].prepareForParsing(parser),
          throwsA(isA<OptionDefinitionError>()));
    });

    test(
        'when duplicate arg positions specified then InvalidOptionConfigurationException is thrown',
        () async {
      final parser = ArgParser();
      expect(() => [argPosOpt, duplicateOpt].prepareForParsing(parser),
          throwsA(isA<OptionDefinitionError>()));
    });

    test(
        'when non-consecutive arg positions specified then InvalidOptionConfigurationException is thrown',
        () async {
      final parser = ArgParser();
      expect(() => [argPosOpt, argPos2Opt].prepareForParsing(parser),
          throwsA(isA<OptionDefinitionError>()));
    });

    test(
        'when first arg position does not start at 0 then InvalidOptionConfigurationException is thrown',
        () async {
      final parser = ArgParser();
      expect(() => [argPos2Opt].prepareForParsing(parser),
          throwsA(isA<OptionDefinitionError>()));
    });
  });

  group('Given an optional positional argument option', () {
    const positionalOpt = StringOption(
      argPos: 0,
    );
    const projectIdOpt = StringOption(
      argName: 'project',
    );
    final options = [positionalOpt, projectIdOpt];

    test('when provided as lone positional argument then parsing succeeds',
        () async {
      final args = ['pos-arg'];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
        env: envVars,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(positionalOpt), equals('pos-arg'));
    });

    test('when provided before named argument then parsing succeeds', () async {
      final args = ['pos-arg', '--project', '123'];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
        env: envVars,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(positionalOpt), equals('pos-arg'));
    });

    test('when provided after named argument then parsing succeeds', () async {
      final args = ['--project', '123', 'pos-arg'];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
        env: envVars,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(positionalOpt), equals('pos-arg'));
    });

    test(
        'when not provided then parsing succeeds and value() throws StateError',
        () async {
      final args = <String>[];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
        env: envVars,
      );
      expect(config.errors, isEmpty);
      expect(() => config.value(positionalOpt), throwsA(isA<StateError>()));
    });

    test('when not provided then parsing succeeds and its value is null',
        () async {
      final args = <String>[];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
        env: envVars,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(positionalOpt), isNull);
    });
  });

  group('Given a mandatory positional argument option', () {
    const positionalOpt = StringOption(
      argPos: 0,
      mandatory: true,
    );
    const projectIdOpt = StringOption(
      argName: 'project',
    );
    final options = [positionalOpt, projectIdOpt];

    test('when provided as lone positional argument then parsing succeeds',
        () async {
      final args = ['pos-arg'];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
        env: envVars,
      );
      expect(config.errors, isEmpty);
      expect(config.value(positionalOpt), equals('pos-arg'));
    });

    test('when provided before named argument then parsing succeeds', () async {
      final args = ['pos-arg', '--project', '123'];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
        env: envVars,
      );
      expect(config.errors, isEmpty);
      expect(config.value(positionalOpt), equals('pos-arg'));
    });

    test('when provided after named argument then parsing succeeds', () async {
      final args = ['--project', '123', 'pos-arg'];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
        env: envVars,
      );
      expect(config.errors, isEmpty);
      expect(config.value(positionalOpt), equals('pos-arg'));
    });

    test('when not provided then parsing has error', () async {
      final args = <String>[];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
        env: envVars,
      );
      expect(config.errors, hasLength(1));
      expect(config.errors.first, 'positional argument 0 is mandatory');
      expect(
        () => config.value(positionalOpt),
        throwsA(isA<StateError>().having(
          (final e) => e.message,
          'message',
          contains(
              'No value available for positional argument 0 due to previous errors'),
        )),
      );
    });
  });

  group('Given two argument options that can be both positional and named', () {
    const firstOpt = StringOption(
      argName: 'first',
      argPos: 0,
    );
    const secondOpt = StringOption(
      argName: 'second',
      argPos: 1,
    );
    final options = [firstOpt, secondOpt];

    test('when provided as lone positional argument then parsing succeeds',
        () async {
      final args = ['1st-arg'];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
        env: envVars,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), equals('1st-arg'));
      expect(config.optionalValue(secondOpt), isNull);
    });

    test('when provided as lone named argument then parsing succeeds',
        () async {
      final args = ['--first', '1st-arg'];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
        env: envVars,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), equals('1st-arg'));
      expect(config.optionalValue(secondOpt), isNull);
    });

    test(
        'when second pos arg is provided as lone named argument then parsing succeeds',
        () async {
      final args = ['--second', '2st-arg'];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
        env: envVars,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), isNull);
      expect(config.optionalValue(secondOpt), equals('2st-arg'));
    });

    test('when provided as two positional args then parsing succeeds',
        () async {
      final args = ['1st-arg', '2nd-arg'];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
        env: envVars,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), equals('1st-arg'));
      expect(config.optionalValue(secondOpt), equals('2nd-arg'));
    });

    test(
        'when provided as 1 positional & 1 named argument then parsing succeeds',
        () async {
      final args = ['1st-arg', '--second', '2nd-arg'];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
        env: envVars,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), equals('1st-arg'));
      expect(config.optionalValue(secondOpt), equals('2nd-arg'));
    });

    test(
        'when provided as 1 named & 1 positional argument then parsing succeeds',
        () async {
      final args = ['--first', '1st-arg', '2nd-arg'];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
        env: envVars,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), equals('1st-arg'));
      expect(config.optionalValue(secondOpt), equals('2nd-arg'));
    });

    test(
        'when provided as 1 named & 1 positional argument in reverse order then parsing succeeds',
        () async {
      final args = ['2nd-arg', '--first', '1st-arg'];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
        env: envVars,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), equals('1st-arg'));
      expect(config.optionalValue(secondOpt), equals('2nd-arg'));
    });

    test('when provided as 2 named arguments then parsing succeeds', () async {
      final args = ['--first', '1st-arg', '--second', '2nd-arg'];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
        env: envVars,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), equals('1st-arg'));
      expect(config.optionalValue(secondOpt), equals('2nd-arg'));
    });

    test(
        'when provided as 2 named arguments in reverse order then parsing succeeds',
        () async {
      final args = ['--second', '2nd-arg', '--first', '1st-arg'];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
        env: envVars,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), equals('1st-arg'));
      expect(config.optionalValue(secondOpt), equals('2nd-arg'));
    });

    test('when not provided then parsing succeeds and both are null', () async {
      final args = <String>[];
      final envVars = <String, String>{};
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
        env: envVars,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), isNull);
      expect(config.optionalValue(secondOpt), isNull);
    });

    test('when superfluous positional argument provided then parsing has error',
        () async {
      final args = ['1st-arg', '2nd-arg', '3rd-arg'];
      final envVars = <String, String>{};

      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
        env: envVars,
      );
      expect(config.errors, hasLength(1));
      expect(
          config.errors.first, "Unexpected positional argument(s): '3rd-arg'");
      expect(config.optionalValue(firstOpt), equals('1st-arg'));
      expect(config.optionalValue(secondOpt), equals('2nd-arg'));
    });

    test(
        'when superfluous positional argument provided after named args then parsing has error',
        () async {
      final args = ['--first', '1st-arg', '--second', '2nd-arg', '3rd-arg'];
      final envVars = <String, String>{};

      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
        env: envVars,
      );
      expect(config.errors, hasLength(1));
      expect(
          config.errors.first, "Unexpected positional argument(s): '3rd-arg'");
      expect(config.optionalValue(firstOpt), equals('1st-arg'));
      expect(config.optionalValue(secondOpt), equals('2nd-arg'));
    });
  });

  group('Given two options that have aliases', () {
    const firstOpt = StringOption(
      argName: 'first',
      argAliases: ['alias-first-a', 'alias-first-b'],
    );
    const secondOpt = StringOption(
      argName: 'second',
      argAliases: ['alias-second-a', 'alias-second-b'],
    );
    final options = [firstOpt, secondOpt];

    test(
        'when the first option is provided using primary name then parsing succeeds',
        () async {
      final args = ['--first', '1st-arg'];
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), equals('1st-arg'));
      expect(config.optionalValue(secondOpt), isNull);
    });

    test(
        'when the first option is provided using first alias then parsing succeeds',
        () async {
      final args = ['--alias-first-a', '1st-arg'];
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), equals('1st-arg'));
      expect(config.optionalValue(secondOpt), isNull);
    });

    test(
        'when the first option is provided using second alias then parsing succeeds',
        () async {
      final args = ['--alias-first-b', '1st-arg'];
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), equals('1st-arg'));
      expect(config.optionalValue(secondOpt), isNull);
    });

    test(
        'when the first option is provided twice using aliases then the last value is used',
        () async {
      final args = ['--alias-first-a', '1st-arg', '--alias-first-b', '2nd-arg'];
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), equals('2nd-arg'));
      expect(config.optionalValue(secondOpt), isNull);
    });

    test(
        'when both options are provided using their aliases then parsing succeeds',
        () async {
      final args = [
        '--alias-first-a',
        '1st-arg',
        '--alias-second-b',
        '2nd-arg'
      ];
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), equals('1st-arg'));
      expect(config.optionalValue(secondOpt), equals('2nd-arg'));
    });
  });

  group('Given two options that are mutually exclusive, disallowing defaults,',
      () {
    const firstOpt = StringOption(
      argName: 'first',
      envName: 'FIRST',
      group: MutuallyExclusive('mutex-group'),
    );
    const secondOpt = StringOption(
      argName: 'second',
      envName: 'SECOND',
      group: MutuallyExclusive('mutex-group'),
    );
    final options = [firstOpt, secondOpt];

    test(
        'when the first of the mut-ex options is provided as argument then parsing succeeds',
        () async {
      final args = ['--first', '1st-arg'];
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), equals('1st-arg'));
      expect(config.optionalValue(secondOpt), isNull);
    });

    test(
        'when the second of the mut-ex options is provided as argument then parsing succeeds',
        () async {
      final args = ['--second', '2nd-arg'];
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), isNull);
      expect(config.optionalValue(secondOpt), equals('2nd-arg'));
    });

    test(
        'when the first of the mut-ex options is provided as env var then parsing succeeds',
        () async {
      final config = Configuration.resolveNoExcept(
        options: options,
        env: {'FIRST': '1st-arg'},
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), equals('1st-arg'));
      expect(config.optionalValue(secondOpt), isNull);
    });

    test(
        'when the second of the mut-ex options is provided as env var then parsing succeeds',
        () async {
      final config = Configuration.resolveNoExcept(
        options: options,
        env: {'SECOND': '2nd-arg'},
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), isNull);
      expect(config.optionalValue(secondOpt), equals('2nd-arg'));
    });

    test(
        'when both mut-ex options are provided as arguments then parsing has error',
        () async {
      final args = ['--first', '1st-arg', '--second', '2nd-arg'];
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
      );
      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        'These options are mutually exclusive: first, second',
      );
    });

    test(
        'when both mut-ex options are provided as arg and env var then parsing has error',
        () async {
      final config = Configuration.resolveNoExcept(
        options: options,
        args: ['--first', '1st-arg'],
        env: {'SECOND': '2nd-arg'},
      );
      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        'These options are mutually exclusive: first, second',
      );
    });

    test(
        'when neither of the mut-ex options are provided then parsing succeeds',
        () async {
      final config = Configuration.resolveNoExcept(
        options: options,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), isNull);
      expect(config.optionalValue(secondOpt), isNull);
    });
  });

  group('Given two options that are mutually exclusive, mandatory,', () {
    const group = MutuallyExclusive(
      'mutex-group',
      mode: MutuallyExclusiveMode.mandatory,
    );
    const firstOpt = StringOption(
      argName: 'first',
      envName: 'FIRST',
      group: group,
    );
    const secondOpt = StringOption(
      argName: 'second',
      envName: 'SECOND',
      group: group,
    );
    final options = [firstOpt, secondOpt];

    test(
        'when the first of the mut-ex options is provided as argument then parsing succeeds',
        () async {
      final args = ['--first', '1st-arg'];
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), equals('1st-arg'));
      expect(config.optionalValue(secondOpt), isNull);
    });

    test(
        'when the second of the mut-ex options is provided as argument then parsing succeeds',
        () async {
      final args = ['--second', '2nd-arg'];
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), isNull);
      expect(config.optionalValue(secondOpt), equals('2nd-arg'));
    });

    test(
        'when the first of the mut-ex options is provided as env var then parsing succeeds',
        () async {
      final config = Configuration.resolveNoExcept(
        options: options,
        env: {'FIRST': '1st-arg'},
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), equals('1st-arg'));
      expect(config.optionalValue(secondOpt), isNull);
    });

    test(
        'when the second of the mut-ex options is provided as env var then parsing succeeds',
        () async {
      final config = Configuration.resolveNoExcept(
        options: options,
        env: {'SECOND': '2nd-arg'},
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), isNull);
      expect(config.optionalValue(secondOpt), equals('2nd-arg'));
    });

    test(
        'when both mut-ex options are provided as arguments then parsing has error',
        () async {
      final args = ['--first', '1st-arg', '--second', '2nd-arg'];
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
      );
      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        'These options are mutually exclusive: first, second',
      );
    });

    test(
        'when both mut-ex options are provided as arg and env var then parsing has error',
        () async {
      final config = Configuration.resolveNoExcept(
        options: options,
        args: ['--first', '1st-arg'],
        env: {'SECOND': '2nd-arg'},
      );
      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        'These options are mutually exclusive: first, second',
      );
    });

    test(
        'when neither of the mut-ex options are provided then parsing has error',
        () async {
      final config = Configuration.resolveNoExcept(
        options: options,
        args: [],
        env: {},
      );
      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        'Option group mutex-group requires one of the options to be provided',
      );
    });
  });

  group(
      'Given two options that are mutually exclusive, mandatory, '
      'and one has a default value,', () {
    const group = MutuallyExclusive(
      'mutex-group',
      mode: MutuallyExclusiveMode.mandatory,
    );
    const firstOpt = StringOption(
      argName: 'first',
      defaultsTo: 'default-first',
      group: group,
    );
    const secondOpt = StringOption(
      argName: 'second',
      group: group,
    );
    final options = [firstOpt, secondOpt];

    test('then option group validation throws error', () async {
      expect(
        () => Configuration.resolveNoExcept(
          options: options,
          args: [],
        ),
        throwsA(isA<OptionDefinitionError>().having(
          (final e) => e.message,
          'message',
          'Option group `mutex-group` does not allow defaults',
        )),
      );
    });
  });

  group(
      'Given two options that are mutually exclusive, allowing defaults, '
      'and first has a default value,', () {
    const group = MutuallyExclusive(
      'mutex-group',
      mode: MutuallyExclusiveMode.allowDefaults,
    );
    const firstOpt = StringOption(
      argName: 'first',
      defaultsTo: 'default-first',
      group: group,
    );
    const secondOpt = StringOption(
      argName: 'second',
      group: group,
    );
    final options = [firstOpt, secondOpt];

    test(
        'when the first of the mut-ex options is provided as argument then parsing succeeds',
        () async {
      final args = ['--first', '1st-arg'];
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), equals('1st-arg'));
      expect(config.optionalValue(secondOpt), isNull);
    });

    test(
        'when the second of the mut-ex options is provided as argument then both have values',
        () async {
      final args = ['--second', '2nd-arg'];
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), equals('default-first'));
      expect(config.optionalValue(secondOpt), equals('2nd-arg'));
    });

    test(
        'when both mut-ex options are provided as arguments then parsing has error',
        () async {
      final args = ['--first', '1st-arg', '--second', '2nd-arg'];
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
      );
      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        'These options are mutually exclusive: first, second',
      );
    });

    test(
        'when neither of the mut-ex options are provided then parsing succeeds with default value',
        () async {
      final config = Configuration.resolveNoExcept(
        options: options,
        args: [],
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), equals('default-first'));
      expect(config.optionalValue(secondOpt), isNull);
    });
  });

  group('Given four mutually exclusive options in two option groups', () {
    const firstOpt = StringOption(
      argName: 'first',
      group: MutuallyExclusive('mutex-group-a'),
    );
    const secondOpt = StringOption(
      argName: 'second',
      group: MutuallyExclusive('mutex-group-a'),
    );
    const thirdOpt = StringOption(
      argName: 'third',
      group: MutuallyExclusive('mutex-group-b'),
    );
    const fourthOpt = StringOption(
      argName: 'fourth',
      group: MutuallyExclusive('mutex-group-b'),
    );
    final options = [firstOpt, secondOpt, thirdOpt, fourthOpt];

    test('when one option from each group is provided then parsing succeeds',
        () async {
      final args = ['--first', '1st-arg', '--third', '3rd-arg'];
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(firstOpt), equals('1st-arg'));
      expect(config.optionalValue(secondOpt), isNull);
      expect(config.optionalValue(thirdOpt), equals('3rd-arg'));
      expect(config.optionalValue(fourthOpt), isNull);
    });

    test(
        'when two options from the same group are provided then parsing has error',
        () async {
      final args = ['--first', '1st-arg', '--second', '2nd-arg'];
      final config = Configuration.resolveNoExcept(
        options: options,
        args: args,
      );
      expect(config.errors, hasLength(1));
      expect(
        config.errors.single,
        'These options are mutually exclusive: first, second',
      );
    });
  });

  group('Given a configuration source option that depends on another option',
      () {
    const projectIdOpt = StringOption(
      configKey: 'config:/project/projectId',
    );
    const configFileOpt = StringOption(
      argName: 'file',
      envName: 'FILE',
      defaultsTo: 'config.yaml',
    );
    final configSource = _dependentConfigBroker(
      {'config:/project/projectId': '123'},
      configFileOpt,
    );

    test('when dependee is specified after depender then parsing succeeds',
        () async {
      final options = [configFileOpt, projectIdOpt];

      final config = Configuration.resolveNoExcept(
        options: options,
        args: ['--file', 'config.yaml'],
        env: <String, String>{},
        configBroker: configSource,
      );
      expect(config.errors, isEmpty);
      expect(config.optionalValue(projectIdOpt), equals('123'));
    });

    test('when dependee is specified before depender then parsing fails',
        () async {
      final options = [projectIdOpt, configFileOpt];

      expect(
        () => Configuration.resolveNoExcept(
          options: options,
          args: ['--file', 'config.yaml'],
          env: <String, String>{},
          configBroker: configSource,
        ),
        throwsA(isA<OptionDefinitionError>().having(
            (final e) => e.message,
            'message',
            'Out-of-order dependency on not-yet-resolved option `file`')),
      );
    });
  });

  group('Given two typed argument options', () {
    const strOpt = StringOption(
      argName: 'string',
    );
    const intOpt = IntOption(
      argName: 'int',
    );

    test(
        'when constructing Configuration '
        'with direct option values of correct type '
        'then it succeeds', () async {
      final config = Configuration.fromValues(
        values: <OptionDefinition, Object>{
          strOpt: '1',
          intOpt: 2,
        },
      );

      expect(config.errors, isEmpty);
      expect(config.optionalValue(strOpt), equals('1'));
      expect(config.optionalValue(intOpt), equals(2));
    });

    test(
        'when constructing Configuration '
        'with direct option values of incorrect type '
        'then construction throws TypeError', () async {
      expect(
        () => Configuration.fromValues(
          values: <OptionDefinition, Object>{
            strOpt: 1,
            intOpt: '2',
          },
        ),
        throwsA(isA<TypeError>().having(
          (final e) => e.toString(),
          'toString()',
          contains("type 'int' is not a subtype of type 'String?' of 'value'"),
        )),
      );
    });

    test(
        'when accessing an unknown option '
        'then an ArgumentError is thrown', () async {
      final config = Configuration.fromValues(
        values: <OptionDefinition, Object>{
          strOpt: '1',
          intOpt: 2,
        },
      );

      const unknownOption = IntOption(argName: 'otherInt');
      expect(
        () => config.optionalValue(unknownOption),
        throwsA(isA<ArgumentError>().having(
          (final e) => e.message,
          'message',
          'option `otherInt` is not part of this configuration',
        )),
      );
    });
  });

  group('Given a Configuration with an options enum', () {
    final Configuration<_TestOption> config = Configuration.fromValues(
      values: <_TestOption, Object>{
        _TestOption.stringOpt: '1',
        _TestOption.intOpt: 2,
      },
    );

    test(
        'when getting the string option value via the enum name '
        'then it succeeds', () async {
      final value = config.findValueOf(enumName: _TestOption.stringOpt.name);
      expect(value, equals('1'));
    });

    test(
        'when getting the string option value via the arg name '
        'then it succeeds', () async {
      final value = config.findValueOf(argName: 'string');
      expect(value, equals('1'));
    });

    test(
        'when getting the string option value via the arg pos  '
        'then it succeeds', () async {
      final value = config.findValueOf(argPos: 0);
      expect(value, equals('1'));
    });

    test(
        'when getting the string option value via the env name '
        'then it succeeds', () async {
      final value = config.findValueOf(envName: 'STRING');
      expect(value, equals('1'));
    });

    test(
        'when getting the string option value via the config key '
        'then it succeeds', () async {
      final value = config.findValueOf(configKey: 'config:/string');
      expect(value, equals('1'));
    });

    test(
        'when getting the int option value via the enum name '
        'then it succeeds', () async {
      final value = config.findValueOf(enumName: _TestOption.intOpt.name);
      expect(value, equals(2));
    });

    test(
        'when getting the int option value via the arg name '
        'then it succeeds', () async {
      final value = config.findValueOf(argName: 'int');
      expect(value, equals(2));
    });

    test(
        'when getting the int option value via the arg pos '
        'then it succeeds', () async {
      final value = config.findValueOf(argPos: 1);
      expect(value, equals(2));
    });

    test(
        'when getting the int option value via the env name '
        'then it succeeds', () async {
      final value = config.findValueOf(envName: 'INT');
      expect(value, equals(2));
    });

    test(
        'when getting the int option value via the config key '
        'then it succeeds', () async {
      final value = config.findValueOf(configKey: 'config:/int');
      expect(value, equals(2));
    });

    test(
        'when getting an unknown option value via the enum name '
        'then it returns null', () async {
      final value = config.findValueOf(enumName: 'unknown');
      expect(value, isNull);
    });

    test(
        'when getting an unknown option value via the arg name '
        'then it succeeds', () async {
      final value = config.findValueOf(argName: 'unknown');
      expect(value, isNull);
    });

    test(
        'when getting an unknown option value via the arg pos '
        'then it succeeds', () async {
      final value = config.findValueOf(argPos: 2);
      expect(value, isNull);
    });

    test(
        'when getting an unknown option value via the env name '
        'then it succeeds', () async {
      final value = config.findValueOf(envName: 'UNKNOWN');
      expect(value, isNull);
    });

    test(
        'when getting an unknown option value via the config key '
        'then it succeeds', () async {
      final value = config.findValueOf(configKey: 'config:/unknown');
      expect(value, isNull);
    });
  });
}

enum _TestOption<V extends Object> implements OptionDefinition<V> {
  stringOpt(
    StringOption(
      argName: 'string',
      argPos: 0,
      envName: 'STRING',
      configKey: 'config:/string',
    ),
  ),
  intOpt(
    IntOption(
      argName: 'int',
      argPos: 1,
      envName: 'INT',
      configKey: 'config:/int',
    ),
  );

  const _TestOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

class _TestConfigBroker implements ConfigurationBroker {
  final Map<String, String> entries;
  final StringOption? requiredOption;

  _TestConfigBroker(
    this.entries, {
    this.requiredOption,
  });

  @override
  String? valueOrNull(final String key, final Configuration cfg) {
    if (requiredOption != null) {
      if (cfg.optionalValue(requiredOption!) == null) {
        return null;
      }
    }
    return entries[key];
  }
}

/// Makes a [ConfigurationBroker] that returns the values from the given map.
/// The returned value is null if the required option does not have a value.
ConfigurationBroker _dependentConfigBroker(
  final Map<String, String> entries,
  final StringOption requiredOption,
) {
  return _TestConfigBroker(entries, requiredOption: requiredOption);
}

/// Default value function for testing.
/// Needs to be a top-level function (or static method) in order to use it with a const constructor.
String _defaultValueFunction() {
  return 'defaultValueFunction';
}

/// Custom value function for testing.
/// Needs to be a top-level function (or static method) in order to use it with a const constructor.
String? _customValueFunction(final Configuration cfg) {
  return 'customValueFunction';
}

/// Custom value function for testing.
/// Needs to be a top-level function (or static method) in order to use it with a const constructor.
String? _customNullFunction(final Configuration cfg) {
  return null;
}
