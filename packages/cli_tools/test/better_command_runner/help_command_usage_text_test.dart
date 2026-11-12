import 'dart:async' show FutureOr, ZoneSpecification, runZoned;

import 'package:cli_tools/better_command_runner.dart'
    show BetterCommandRunner, MessageOutput, BetterCommand;
import 'package:config/config.dart'
    show Configuration, OptionDefinition, UsageException;
import 'package:test/test.dart';

void main() => _runTests();

const _exeName = 'mock';
const _exeDescription = 'A mock command to test `help -h` with MessageOutput.';
const _moMockText = 'SUCCESS: `MessageOutput.usageLogger`';
const _moExceptionText = 'SUCCESS: `MessageOutput.usageExceptionLogger`';
const _invalidOption = '-z';

const _helpUsageExpectedKeyLines = <String>[
  'Show help for a command.',
  'Usage: mock help [<command>]',
  'Available subcommands:',
  'A dummy subcommand',
  'Run "mock help" to see global options.',
];

const _unknownOptionLine = 'help: Unknown option: $_invalidOption.';

class _DummySubcommand extends BetterCommand<OptionDefinition, void> {
  @override
  String get name => 'dummy';

  @override
  String get description => 'A dummy subcommand';

  @override
  FutureOr<void> runWithConfig(
    final Configuration<OptionDefinition> commandConfig,
  ) {}
}

BetterCommandRunner<OptionDefinition, void> _buildBetterRunner() =>
    BetterCommandRunner(
      _exeName,
      _exeDescription,
      messageOutput: MessageOutput(
        usageLogger: (final usage) {
          print(_moMockText);
          print(usage);
        },
        usageExceptionLogger: (final exception) {
          print(_moExceptionText);
          print(exception.message);
          print(exception.usage);
        },
      ),
      subcommands: [_DummySubcommand()],
    );

void _runTests() {
  group(
    'Given a BetterCommandRunner with a subcommand and with custom MessageOutput',
    () {
      for (final args in [
        ['help', '-h'],
        ['help', 'help'],
        ['help', '-h', 'help'],
        ['help', '-h', 'help', '-h'],
        ['help', '-h', 'help', '-h', 'help'],
        ['help', '-h', 'help', '-h', 'help', '-h'],
      ]) {
        _testsForValidHelpUsageRequests(args);
      }
      for (final args in [
        ['help', 'help', _invalidOption],
        ['help', _invalidOption, 'help'],
      ]) {
        _testsForInvalidHelpUsageRequests(args);
      }
    },
  );
}

void _testsForValidHelpUsageRequests(final List<String> args) {
  group('when $args is received', () {
    final betterRunnerOutput = StringBuffer();
    late final Object? betterRunnerExitCode;
    setUpAll(() async {
      betterRunnerExitCode = await runZoned(
        () async => await _buildBetterRunner().run(args),
        zoneSpecification: ZoneSpecification(
          print: (final _, final _, final _, final String line) {
            betterRunnerOutput.writeln(line);
          },
        ),
      );
    });
    test('then MessageOutput is not bypassed', () {
      expect(
        betterRunnerOutput.toString(),
        contains(_moMockText),
      );
    });
    test('then the usage text describes the help command', () {
      expect(
        betterRunnerOutput.toString(),
        stringContainsInOrder([
          _moMockText,
          ..._helpUsageExpectedKeyLines,
        ]),
      );
    });
    test('then the run completes', () {
      expect(betterRunnerExitCode, isNull);
    });
  });
}

void _testsForInvalidHelpUsageRequests(final List<String> args) {
  group('when $args is received', () {
    final betterRunnerOutput = StringBuffer();
    UsageException? betterRunnerException;
    setUpAll(() async {
      try {
        await runZoned(
          () async => await _buildBetterRunner().run(args),
          zoneSpecification: ZoneSpecification(
            print: (final _, final _, final _, final String line) {
              betterRunnerOutput.writeln(line);
            },
          ),
        );
      } on UsageException catch (e) {
        betterRunnerException = e;
      }
    });
    test('then it throws a UsageException', () {
      expect(betterRunnerException, isA<UsageException>());
    });
    test('then MessageOutput is not bypassed', () {
      final exception = betterRunnerException;
      expect(exception, isA<UsageException>());
      expect(
        betterRunnerOutput.toString(),
        stringContainsInOrder(
          [
            _moExceptionText,
            exception!.message,
            exception.usage,
          ],
        ),
      );
    });
    test('then the error text reports the unknown option', () {
      expect(
        betterRunnerOutput.toString(),
        stringContainsInOrder([
          _moExceptionText,
          _unknownOptionLine,
        ]),
      );
    });
  });
}
