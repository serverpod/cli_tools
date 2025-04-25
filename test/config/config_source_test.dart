import 'package:test/test.dart';

import 'package:cli_tools/config.dart';

void main() {
  group(
      'Given a MultiDomainConfigBroker with two domains and correctly configured options',
      () {
    const yamlContentOpt = StringOption(
      argName: 'yaml-content',
      envName: 'YAML_CONTENT',
    );
    const jsonContentOpt = StringOption(
      argName: 'json-content',
      envName: 'JSON_CONTENT',
    );
    const yamlProjectIdOpt = StringOption(
      configKey: 'yamlOption:/project/projectId',
    );
    const jsonProjectIdOpt = StringOption(
      configKey: 'jsonOption:/project/projectId',
    );
    final options = [
      yamlContentOpt,
      jsonContentOpt,
      yamlProjectIdOpt,
      jsonProjectIdOpt,
    ];

    late ConfigurationBroker configSource;

    setUp(() {
      configSource = MultiDomainConfigBroker.prefix({
        'yamlOption': OptionContentConfigProvider(
          contentOption: yamlContentOpt,
          format: ConfigEncoding.yaml,
        ),
        'jsonOption': OptionContentConfigProvider(
          contentOption: jsonContentOpt,
          format: ConfigEncoding.json,
        ),
      });
    });

    test(
        'when the YAML content option has data '
        'then the correct value is retrieved', () async {
      final config = Configuration.resolve(
        options: options,
        args: [
          '--yaml-content',
          '''
project:
  projectId: '123'
''',
        ],
        configBroker: configSource,
      );

      expect(config.errors, isEmpty);
      expect(config.optionalValue(yamlProjectIdOpt), equals('123'));
      expect(config.optionalValue(jsonProjectIdOpt), isNull);
    });

    test(
        'when the JSON content option has data '
        'then the correct value is retrieved', () async {
      final config = Configuration.resolve(
        options: options,
        args: [
          '--json-content',
          '''
{
  "project": {
    "projectId": "123"
  }
}
''',
        ],
        configBroker: configSource,
      );

      expect(config.errors, isEmpty);
      expect(config.optionalValue(yamlProjectIdOpt), isNull);
      expect(config.optionalValue(jsonProjectIdOpt), equals('123'));
    });

    test(
        'when the YAML content option has data of the wrong type '
        'then an appropriate error is registered', () async {
      final config = Configuration.resolve(
        options: options,
        args: [
          '--yaml-content',
          '''
project:
  projectId: 123
''',
        ],
        configBroker: configSource,
      );

      expect(
          config.errors,
          contains(
            equals(
              'configuration key `yamlOption:/project/projectId` value 123 is of type int, not String.',
            ),
          ));
      expect(
        () => config.optionalValue(yamlProjectIdOpt),
        throwsA(isA<StateError>()),
      );
      expect(config.optionalValue(jsonProjectIdOpt), isNull);
    });

    test(
        'when the JSON content option has data of the wrong type '
        'then an appropriate error is registered', () async {
      final config = Configuration.resolve(
        options: options,
        args: [
          '--json-content',
          '''
{
  "project": {
    "projectId": 123
  }
}
''',
        ],
        configBroker: configSource,
      );

      expect(
          config.errors,
          contains(
            equals(
              'configuration key `jsonOption:/project/projectId` value 123 is of type int, not String.',
            ),
          ));
      expect(
        () => config.optionalValue(jsonProjectIdOpt),
        throwsA(isA<StateError>()),
      );
      expect(config.optionalValue(yamlProjectIdOpt), isNull);
    });

    test(
        'when the YAML content option has malformed data '
        'then an appropriate error is registered', () async {
      final config = Configuration.resolve(
        options: options,
        args: [
          '--yaml-content',
          '''
project:
projectId:123
''',
        ],
        configBroker: configSource,
      );

      expect(
          config.errors,
          contains(contains(
            'Failed to resolve configuration key `yamlOption:/project/projectId`: Error on line',
          )));
      expect(
        () => config.optionalValue(yamlProjectIdOpt),
        throwsA(isA<StateError>()),
      );
      expect(config.optionalValue(jsonProjectIdOpt), isNull);
    });

    test(
        'when the JSON content option has malformed data '
        'then an appropriate error is registered', () async {
      final config = Configuration.resolve(
        options: options,
        args: [
          '--json-content',
          '''
{
  "project": {
    "projectId":
  }
}
''',
        ],
        configBroker: configSource,
      );

      expect(
          config.errors,
          contains(contains(
            'Failed to resolve configuration key `jsonOption:/project/projectId`: FormatException: Unexpected character',
          )));
      expect(
        () => config.optionalValue(jsonProjectIdOpt),
        throwsA(isA<StateError>()),
      );
      expect(config.optionalValue(yamlProjectIdOpt), isNull);
    });
  });

  group(
      'Given a MultiDomainConfigBroker with a domain and misconfigured options',
      () {
    const yamlContentOpt = StringOption(
      argName: 'yaml-content',
      envName: 'YAML_CONTENT',
    );
    const yamlProjectIdOpt = StringOption(
      configKey: 'yamlOption:/project/projectId',
    );
    const missingDomainOpt = StringOption(
      configKey: '/project/projectId',
    );
    const unknownDomainOpt = StringOption(
      configKey: 'unknown:/project/projectId',
    );
    final options = [
      yamlContentOpt,
      yamlProjectIdOpt,
      missingDomainOpt,
      unknownDomainOpt,
    ];

    late ConfigurationBroker configSource;

    setUp(() {
      configSource = MultiDomainConfigBroker.prefix({
        'yamlOption': OptionContentConfigProvider(
          contentOption: yamlContentOpt,
          format: ConfigEncoding.yaml,
        ),
      });
    });

    test(
        'when creating the configuration '
        'then the expected errors are registered', () async {
      expect(
        () => Configuration.resolve(
          options: options,
          configBroker: configSource,
        ),
        throwsA(isA<StateError>().having(
          (final e) => e.message,
          'message',
          equals(
            'No matching configuration domain for key: /project/projectId',
          ),
        )),
      );
    });
  });
}
