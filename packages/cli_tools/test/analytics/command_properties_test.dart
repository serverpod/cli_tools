import 'package:args/command_runner.dart';
import 'package:cli_tools/src/analytics/command_properties.dart';
import 'package:test/test.dart';

class TemplateCommand extends Command<void> {
  static const commandName = 'template';

  @override
  String get description => 'Template subcommand';

  @override
  String get name => commandName;

  TemplateCommand() {
    argParser.addOption('path', abbr: 'p');
  }

  @override
  void run() {}
}

class CreateCommand extends Command<void> {
  static const commandName = 'create';

  @override
  String get description => 'Create command';

  @override
  String get name => commandName;

  CreateCommand() {
    argParser.addFlag('mini', abbr: 'm', negatable: false);
    argParser.addFlag('force', abbr: 'f', defaultsTo: true);
    argParser.addOption('name', abbr: 'n');
    argParser.addMultiOption('tag', abbr: 't');
    addSubcommand(TemplateCommand());
  }

  @override
  void run() {}
}

void main() {
  group('Given command properties builder', () {
    late CommandRunner<void> runner;

    setUp(() {
      runner = CommandRunner<void>('tool', 'test cli')
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
        final args = [
          CreateCommand.commandName,
          '--mini',
          '--name',
          'secret'
        ];
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
        final args = [
          CreateCommand.commandName,
          '--tag',
          'a',
          '--tag',
          'b'
        ];
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
