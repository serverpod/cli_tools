import 'dart:async' show FutureOr;

import 'package:cli_tools/better_command_runner.dart'
    show BetterCommand, BetterCommandRunner, RunContext;
import 'package:cli_tools/src/analytics/command_properties.dart';
import 'package:config/config.dart'
    show StringOption, FlagOption, MultiStringOption;
import 'package:test/test.dart';

class TemplateCommand extends BetterCommand {
  static const commandName = 'template';

  @override
  String get description => 'Template subcommand';

  @override
  String get name => commandName;

  TemplateCommand()
      : super(options: const [StringOption(argName: 'path', argAbbrev: 'p')]);

  @override
  FutureOr? run(final RunContext runContext) {
    return null;
  }
}

class CreateCommand extends BetterCommand {
  static const commandName = 'create';

  @override
  String get description => 'Create command';

  @override
  String get name => commandName;

  CreateCommand()
      : super(options: const [
          FlagOption(argName: 'mini', argAbbrev: 'm', negatable: false),
          FlagOption(argName: 'force', argAbbrev: 'f', defaultsTo: true),
          StringOption(argName: 'name', argAbbrev: 'n'),
          MultiStringOption(argName: 'tag', argAbbrev: 't')
        ]) {
    addSubcommand(TemplateCommand());
  }

  @override
  FutureOr? run(final RunContext runContext) {
    return null;
  }
}

void main() {
  group('Given command properties builder', () {
    late BetterCommandRunner runner;

    setUp(() {
      runner = BetterCommandRunner('tool', 'test cli')
        ..addCommand(CreateCommand());
    });

    test(
      'when running with flag and positional '
      'then flags are preserved and positionals masked',
      () {
        final args = [CreateCommand.commandName, '--mini', 'project'];
        final results = runner.parse(args);

        final properties = buildCommandPropertiesForAnalytics(
          topLevelResults: results,
          argParser: runner.argParser,
          commands: runner.commands,
        );

        expect(properties, containsPair('flag_mini', true));
        expect(properties['full_command'], 'create --mini xxx');
      },
    );

    test(
      'when running with option value '
      'then value is masked in properties and full command',
      () {
        final args = [CreateCommand.commandName, '--mini', '--name', 'secret'];
        final results = runner.parse(args);

        final properties = buildCommandPropertiesForAnalytics(
          topLevelResults: results,
          argParser: runner.argParser,
          commands: runner.commands,
        );

        expect(properties, containsPair('flag_mini', true));
        expect(properties, containsPair('option_name', 'xxx'));
        expect(properties['full_command'], 'create --mini --name xxx');
      },
    );

    test(
      'when running with inline long option value '
      'then value is masked and no extra arg is consumed',
      () {
        final args = [CreateCommand.commandName, '--name=secret', 'extra'];
        final results = runner.parse(args);

        final properties = buildCommandPropertiesForAnalytics(
          topLevelResults: results,
          argParser: runner.argParser,
          commands: runner.commands,
        );

        expect(properties, containsPair('option_name', 'xxx'));
        expect(properties['full_command'], 'create --name xxx xxx');
      },
    );

    test(
      'when running with inline short option value '
      'then value is masked',
      () {
        final args = [CreateCommand.commandName, '-n=secret'];
        final results = runner.parse(args);

        final properties = buildCommandPropertiesForAnalytics(
          topLevelResults: results,
          argParser: runner.argParser,
          commands: runner.commands,
        );

        expect(properties, containsPair('option_name', 'xxx'));
        expect(properties['full_command'], 'create --name xxx');
      },
    );

    test(
      'when running with negated flag '
      'then full command preserves negation and property is false',
      () {
        final args = [CreateCommand.commandName, '--no-force'];
        final results = runner.parse(args);

        final properties = buildCommandPropertiesForAnalytics(
          topLevelResults: results,
          argParser: runner.argParser,
          commands: runner.commands,
        );

        expect(properties, containsPair('flag_force', false));
        expect(properties['full_command'], 'create --no-force');
      },
    );

    test(
      'when running with repeated multi options '
      'then each value is masked',
      () {
        final args = [CreateCommand.commandName, '--tag', 'a', '--tag', 'b'];
        final results = runner.parse(args);

        final properties = buildCommandPropertiesForAnalytics(
          topLevelResults: results,
          argParser: runner.argParser,
          commands: runner.commands,
        );

        expect(properties['option_tag'], equals(['xxx', 'xxx']));
        expect(properties['full_command'], 'create --tag xxx --tag xxx');
      },
    );

    test(
      'when running with short flag and short option '
      'then option value is masked',
      () {
        final args = [CreateCommand.commandName, '-m', '-n', 'secret'];
        final results = runner.parse(args);

        final properties = buildCommandPropertiesForAnalytics(
          topLevelResults: results,
          argParser: runner.argParser,
          commands: runner.commands,
        );

        expect(properties, containsPair('flag_mini', true));
        expect(properties, containsPair('option_name', 'xxx'));
        expect(properties['full_command'], 'create --mini --name xxx');
      },
    );

    test(
      'when running with subcommand option '
      'then subcommand parser is used for masking',
      () {
        final args = [
          CreateCommand.commandName,
          TemplateCommand.commandName,
          '--path',
          '/tmp/secret'
        ];
        final results = runner.parse(args);

        final properties = buildCommandPropertiesForAnalytics(
          topLevelResults: results,
          argParser: runner.argParser,
          commands: runner.commands,
        );

        expect(properties, containsPair('option_path', 'xxx'));
        expect(properties['full_command'], 'create template --path xxx');
      },
    );

    test(
      'when running with double dash '
      'then all following tokens are masked',
      () {
        final args = [
          CreateCommand.commandName,
          '--name',
          'secret',
          '--',
          '--not-option',
          'literal'
        ];
        final results = runner.parse(args);

        final properties = buildCommandPropertiesForAnalytics(
          topLevelResults: results,
          argParser: runner.argParser,
          commands: runner.commands,
        );

        expect(properties, containsPair('option_name', 'xxx'));
        expect(
          properties['full_command'],
          'create --name xxx -- xxx xxx',
        );
      },
    );
  });
}
