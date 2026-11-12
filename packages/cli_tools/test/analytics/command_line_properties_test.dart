import 'package:cli_tools/src/analytics/command_line_properties.dart';
import 'package:config/command.dart';
import 'package:config/config.dart';
import 'package:test/test.dart';

const _createOptions = <OptionDefinition>[
  FlagOption(argName: 'mini', argAbbrev: 'm', negatable: false),
  FlagOption(argName: 'force', argAbbrev: 'f', defaultsTo: true),
  StringOption(
    argName: 'name',
    argAbbrev: 'n',
    argAliases: ['title'],
  ),
  IntOption(argName: 'jobs', argAbbrev: 'j'),
  MultiStringOption.noSplit(argName: 'tag', argAbbrev: 't'),
];

Command<OptionDefinition, void> _createLeafCommand() {
  return CommandImpl.leafWithRunFunction<OptionDefinition, void>(
    name: 'create',
    description: 'Create command',
    aliases: const ['new'],
    options: const <OptionDefinition>[
      ..._createOptions,
      StringOption(argPos: 0),
    ],
    run: (final _) {},
  );
}

Command<OptionDefinition, void> _createBranchCommand({
  required final List<Command<OptionDefinition, void>> subcommands,
}) {
  return CommandImpl.branch<OptionDefinition, void>(
    name: 'create',
    description: 'Create command',
    aliases: const ['new'],
    persistentOptions: _createOptions,
    subcommands: subcommands,
  );
}

Command<OptionDefinition, void> _templateCommand() {
  return CommandImpl.leafWithRunFunction<OptionDefinition, void>(
    name: 'template',
    description: 'Template subcommand',
    options: <OptionDefinition>[
      const StringOption(argName: 'path', argAbbrev: 'p'),
    ],
    run: (final _) {},
  );
}

void main() {
  group('Given a create command', () {
    late CommandRunner<OptionDefinition, void> runner;

    setUp(() {
      runner = CommandRunner<OptionDefinition, void>(
        'tool',
        'test cli',
        ignoreUnexpectedPositionalArgs: true,
        subcommands: [_createLeafCommand()],
      );
    });

    CommandContext<OptionDefinition, void> contextFor(
      final List<String> args,
    ) {
      return runner.resolveConfigurations(
        args,
        null,
        ContextProvider(),
      )!;
    }

    Map<String, dynamic> propertiesFor(final List<String> args) {
      return buildCommandLinePropertiesForAnalytics(contextFor(args));
    }

    group('when running with a flag and a positional', () {
      late Map<String, dynamic> properties;

      setUp(() {
        properties = propertiesFor(['create', '--mini', 'project']);
      });

      test('then the flag value is recorded', () {
        expect(properties, containsPair('flag_mini', true));
      });

      test('then the positional is masked in the command', () {
        expect(properties['full_command'], 'create --mini xxx');
      });

      test('then the positional value is not recorded', () {
        expect(properties.toString(), isNot(contains('project')));
      });
    });

    group('when running with an option value', () {
      late Map<String, dynamic> properties;

      setUp(() {
        properties = propertiesFor(['create', '--mini', '--name', 'secret']);
      });

      test('then the flag and the masked option are recorded', () {
        expect(properties, containsPair('flag_mini', true));
        expect(properties, containsPair('option_name', 'xxx'));
      });

      test('then the command uses the canonical option name', () {
        expect(properties['full_command'], 'create --mini --name xxx');
      });
    });

    test(
      'when running with inline long option value '
      'then value is masked and no extra arg is consumed',
      () {
        final properties = propertiesFor([
          'create',
          '--name=secret',
          'extra',
        ]);

        expect(properties, containsPair('option_name', 'xxx'));
        expect(properties['full_command'], 'create --name xxx xxx');
      },
    );

    test(
      'when running with inline short option value '
      'then value is masked',
      () {
        final properties = propertiesFor(['create', '-n=secret']);

        expect(properties, containsPair('option_name', 'xxx'));
        expect(properties['full_command'], 'create --name xxx');
      },
    );

    test(
      'when running with a negated flag '
      'then the command preserves the negation and the property is false',
      () {
        final properties = propertiesFor(['create', '--no-force']);

        expect(properties, containsPair('flag_force', false));
        expect(properties['full_command'], 'create --no-force');
      },
    );

    test(
      'when running with repeated multi options '
      'then each value is masked',
      () {
        final properties = propertiesFor([
          'create',
          '--tag',
          'a',
          '--tag',
          'b',
        ]);

        expect(properties['option_tag'], equals(['xxx', 'xxx']));
        expect(properties['full_command'], 'create --tag xxx --tag xxx');
      },
    );

    test(
      'when running with short options '
      'then they are written with their long names',
      () {
        final properties = propertiesFor(['create', '-m', '-n', 'secret']);

        expect(properties, containsPair('flag_mini', true));
        expect(properties, containsPair('option_name', 'xxx'));
        expect(properties['full_command'], 'create --mini --name xxx');
      },
    );

    test(
      'when running with an option alias '
      'then the canonical option name is used',
      () {
        final properties = propertiesFor(['create', '--title', 'secret']);

        expect(properties, containsPair('option_name', 'xxx'));
        expect(properties['full_command'], 'create --name xxx');
      },
    );

    test(
      'when running with a command alias '
      'then the canonical command name is used',
      () {
        final properties = propertiesFor(['new', '--mini']);

        expect(properties['full_command'], 'create --mini');
      },
    );

    test(
      'when running with an integer option '
      'then the number is masked',
      () {
        final properties = propertiesFor(['create', '--jobs', '4']);

        expect(properties, containsPair('option_jobs', 'xxx'));
        expect(properties['full_command'], 'create --jobs xxx');
      },
    );

    test(
      'when running with a double dash '
      'then the following words are masked',
      () {
        final properties = propertiesFor([
          'create',
          '--name',
          'secret',
          '--',
          '--not-option',
          'literal',
        ]);

        expect(properties, containsPair('option_name', 'xxx'));
        expect(
          properties['full_command'],
          'create --name xxx -- xxx xxx',
        );
      },
    );
  });

  group('Given create has a template subcommand', () {
    late CommandRunner<OptionDefinition, void> runner;

    setUp(() {
      runner = CommandRunner<OptionDefinition, void>(
        'tool',
        'test cli',
        ignoreUnexpectedPositionalArgs: true,
        subcommands: [
          _createBranchCommand(subcommands: [_templateCommand()]),
        ],
      );
    });

    test(
      'when running the subcommand with an option '
      'then the subcommand option is masked',
      () {
        final context = runner.resolveConfigurations(
          ['create', 'template', '--path', '/tmp/secret'],
          const {},
          ContextProvider(),
        )!;

        final properties = buildCommandLinePropertiesForAnalytics(
          context.leaf(),
        );

        expect(properties, containsPair('option_path', 'xxx'));
        expect(properties['full_command'], 'create template --path xxx');
      },
    );

    test(
      'when help is requested '
      'then the help flag is recorded',
      () {
        final context = runner.resolveConfigurations(
          ['--help'],
          const {},
          ContextProvider(),
        )!;

        final properties = buildCommandLinePropertiesForAnalytics(context);

        expect(properties, containsPair('flag_help', true));
        expect(properties['full_command'], '--help');
      },
    );
  });
}
