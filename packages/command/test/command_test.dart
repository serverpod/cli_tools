import 'dart:async';

import 'package:command/command.dart';
import 'package:config/config.dart';
import 'package:test/test.dart';

enum BespokeGlobalOption<V extends Object> implements OptionDefinition<V> {
  quiet(NewCommandRunnerFlags.quietOption),
  verbose(NewCommandRunnerFlags.verboseOption),
  analytics(NewCommandRunnerFlags.analyticsOption),
  age(IntOption(argName: 'age', helpText: 'Required age', min: 0, max: 100))
  ;

  const BespokeGlobalOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

class MockCommand extends NewCommand {
  static String commandName = 'mock-command';

  MockCommand({super.messageOutput})
    : super(
        options: [
          const StringOption(
            argName: 'name',
            defaultsTo: 'serverpod',
            allowedValues: ['serverpod', 'stockholm'],
          ),
        ],
      );

  @override
  String get description => 'Mock command used for testing';

  @override
  String get name => commandName;

  @override
  FutureOr? run(RunContext runContext) {
    return null;
  }
}

void main() {
  group('Given a command registered in the command runner '
      'with analytics set up and default global options', () {
    final infos = <String>[];
    final analyticsEvents = <String>[];
    final messageOutput = MessageOutput(
      usageLogger: (u) => infos.add(u),
    );

    final testCommand = MockCommand(
      messageOutput: messageOutput,
    );
    final runner = NewCommandRunner(
      'test',
      'test project',
      onAnalyticsEvent: (e, _) => analyticsEvents.add(e),
      messageOutput: messageOutput,
    )..addCommand(testCommand);

    setUp(() {
      infos.clear();
      analyticsEvents.clear();
    });

    test('when running base command with --help flag '
        'then global usage is printed to commands logInfo', () async {
      await runner.run(['--help']);

      expect(infos, hasLength(1));
      expect(infos.single, runner.usage);
      expect(
        infos.single,
        stringContainsInOrder([
          'Usage: test <command> [arguments]',
          'Global options:',
          '-h, --help',
          'Print this usage information.',
          '-q, --quiet',
          'Suppress all cli output. Is overridden by  -v, --verbose.',
          '-v, --verbose',
          'Prints additional information useful for development. Overrides --q, --quiet.',
          '-a, --[no-]analytics',
          'Toggles if analytics data is sent.',
        ]),
      );
    });

    test('when running base command with --help flag '
        'then help analytics is sent', () async {
      await runner.run(['--help']);

      await Future.delayed(const Duration(milliseconds: 100));
      expect(analyticsEvents, hasLength(1));
      expect(analyticsEvents.single, 'help');
    });

    test('when running with subcommand `help` '
        'then help analytics is sent', () async {
      await runner.run(['help']);

      await Future.delayed(const Duration(milliseconds: 100));
      expect(analyticsEvents, hasLength(1));
      expect(analyticsEvents.single, 'help');
    });

    test('when running with subcommand `mock-command` '
        'then subcommand analytics is sent', () async {
      await runner.run([MockCommand.commandName]);

      await Future.delayed(const Duration(milliseconds: 100));
      expect(analyticsEvents, hasLength(1));
      expect(analyticsEvents.single, 'mock-command');
    });

    test('when running with invalid subcommand '
        'then invalid command analytics is sent', () async {
      await runner.run(['no-such-command']).catchError((_) {});

      await Future.delayed(const Duration(milliseconds: 100));
      expect(analyticsEvents, hasLength(1));
      expect(analyticsEvents.single, 'invalid');
    });

    test('when running with subcommand `mock-command` '
        'and --no-analytics flag '
        'then subcommand analytics is not sent', () async {
      await runner.run([MockCommand.commandName, '--no-analytics']);

      await Future.delayed(const Duration(milliseconds: 100));
      expect(analyticsEvents, isEmpty);
    });
  });

  group('Given a command registered in the command runner '
      'with analytics set up and empty global options', () {
    final infos = <String>[];
    final analyticsEvents = <String>[];
    final messageOutput = MessageOutput(
      usageLogger: (u) => infos.add(u),
    );

    final testCommand = MockCommand(
      messageOutput: messageOutput,
    );
    final runner = NewCommandRunner(
      'test',
      'test project',
      onAnalyticsEvent: (e, _) => analyticsEvents.add(e),
      globalOptions: <OptionDefinition>[],
      messageOutput: messageOutput,
    )..addCommand(testCommand);

    setUp(() {
      infos.clear();
      analyticsEvents.clear();
    });

    test(
      'when running base command with --help flag '
      'then global usage is printed to commands logInfo',
      () async {
        await runner.run(['--help']);

        expect(infos, hasLength(1));
        expect(infos.single, runner.usage);
        expect(
          infos.single,
          allOf(
            stringContainsInOrder([
              'Usage: test <command> [arguments]',
              'Global options:',
              '-h, --help',
              'Print this usage information.',
            ]),
            isNot(contains('-q, --quiet')),
            isNot(contains('-v, --verbose')),
            isNot(contains('-a, --[no-]analytics')),
          ),
        );
      },
    );
  });

  group('Given a command registered in the command runner '
      'without analytics set up and default global options', () {
    final infos = <String>[];
    final messageOutput = MessageOutput(
      usageLogger: (u) => infos.add(u),
    );

    final testCommand = MockCommand(
      messageOutput: messageOutput,
    );
    final runner = NewCommandRunner(
      'test',
      'test project',
      messageOutput: messageOutput,
    )..addCommand(testCommand);

    setUp(() {
      infos.clear();
    });

    test('when running base command with --help flag '
        'then global usage is printed to commands logInfo', () async {
      await runner.run(['--help']);

      expect(infos, hasLength(1));
      expect(infos.single, runner.usage);
      expect(
        infos.single,
        allOf(
          stringContainsInOrder([
            'Usage: test <command> [arguments]',
            'Global options:',
            '-h, --help',
            'Print this usage information.',
            '-q, --quiet',
            'Suppress all cli output. Is overridden by  -v, --verbose.',
            '-v, --verbose',
            'Prints additional information useful for development. Overrides --q, --quiet.',
          ]),
          isNot(
            contains(
              '-a, --[no-]analytics',
            ),
          ),
        ),
      );
    });
  });

  group('Given a command registered in the command runner '
      'with additional global options', () {
    final infos = <String>[];
    final messageOutput = MessageOutput(
      usageLogger: (u) => infos.add(u),
    );

    final testCommand = MockCommand(
      messageOutput: messageOutput,
    );
    final runner = NewCommandRunner(
      'test',
      'test project',
      globalOptions: BespokeGlobalOption.values,
      messageOutput: messageOutput,
    )..addCommand(testCommand);

    setUp(() {
      infos.clear();
    });

    test(
      'when running base command with --help flag '
      'then global usage is printed to commands logInfo',
      () async {
        await runner.run(['--help']);

        expect(infos, hasLength(1));
        expect(infos.single, runner.usage);
        expect(
          infos.single,
          stringContainsInOrder([
            'Usage: test <command> [arguments]',
            'Global options:',
            '-h, --help',
            'Print this usage information.',
            '-q, --quiet',
            'Suppress all cli output. Is overridden by  -v, --verbose.',
            '-v, --verbose',
            'Prints additional information useful for development. Overrides --q, --quiet.',
            '-a, --[no-]analytics',
            'Toggles if analytics data is sent.',
            '--age=<integer>',
            'Required age',
            'Available commands:',
            'mock-command',
            'Mock command used for testing',
          ]),
        );
      },
    );

    test(
      'when running with subcommand `help` '
      'then global usage is printed to commands logInfo',
      () async {
        await runner.run(['help']);

        expect(infos, hasLength(1));
        expect(infos.single, runner.usage);
        expect(
          infos.single,
          stringContainsInOrder([
            'Usage: test <command> [arguments]',
            'Global options:',
            '-h, --help',
            'Print this usage information.',
            '-q, --quiet',
            'Suppress all cli output. Is overridden by  -v, --verbose.',
            '-v, --verbose',
            'Prints additional information useful for development. Overrides --q, --quiet.',
            '-a, --[no-]analytics',
            'Toggles if analytics data is sent.',
            '--age=<integer>',
            'Required age',
            'Available commands:',
            'mock-command',
            'Mock command used for testing',
          ]),
        );
      },
    );

    test(
      'when running with subcommand `mock-command` and option --help flag '
      'then subcommand usage is printed to commands logInfo',
      () async {
        await runner.run([MockCommand.commandName, '--help']);

        expect(infos, hasLength(1));
        expect(infos.single, testCommand.usage);
        expect(
          infos.single,
          stringContainsInOrder([
            'Usage: test mock-command [arguments]',
            '-h, --help',
            'Print this usage information.',
            '--name',
            '[serverpod (default), stockholm]',
          ]),
        );
      },
    );
  });
}
