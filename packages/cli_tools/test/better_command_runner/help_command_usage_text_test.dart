import 'dart:async' show ZoneSpecification, runZoned;

import 'package:args/command_runner.dart' show CommandRunner, UsageException;
import 'package:cli_tools/better_command_runner.dart'
    show BetterCommandRunner, MessageOutput;
import 'package:test/test.dart';

void main() => _runTests();

const _exeName = 'mock';
const _exeDescription = 'A mock command to test `help -h` with MessageOutput.';
const _moMockText = 'SUCCESS: `MessageOutput.usageLogger`';
const _moExceptionText = 'SUCCESS: `MessageOutput.usageExceptionLogger`';
const _invalidOption = '-z';

CommandRunner _buildUpstreamRunner() => CommandRunner(
      _exeName,
      _exeDescription,
    );

BetterCommandRunner _buildBetterRunner() => BetterCommandRunner(
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
    );

void _runTests() {
  group('Given a BetterCommandRunner with custom MessageOutput', () {
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
      ['help', '-h', _invalidOption],
      ['help', 'help', _invalidOption],
      ['help', _invalidOption, 'help'],
      ['help', 'help', '-h', _invalidOption],
      ['help', _invalidOption, 'help', '-h', _invalidOption],
    ]) {
      _testsForInvalidHelpUsageRequests(args);
    }
  });
}

void _testsForValidHelpUsageRequests(final List<String> args) {
  group('when $args is received', () {
    final betterRunnerOutput = StringBuffer();
    final upstreamRunnerOutput = StringBuffer();
    late final Object? betterRunnerExitCode;
    late final Object? upstreamRunnerExitCode;
    setUpAll(() async {
      betterRunnerExitCode = await runZoned(
        () async => await _buildBetterRunner().run(args),
        zoneSpecification: ZoneSpecification(
            print: (final _, final __, final ___, final String line) {
          betterRunnerOutput.writeln(line);
        }),
      );
      upstreamRunnerExitCode = await runZoned(
        () async => await _buildUpstreamRunner().run(args),
        zoneSpecification: ZoneSpecification(
            print: (final _, final __, final ___, final String line) {
          upstreamRunnerOutput.writeln(line);
        }),
      );
    });
    test('then MessageOutput is not bypassed', () {
      expect(
        betterRunnerOutput.toString(),
        contains(_moMockText),
      );
    });
    test('then it can subsume upstream HelpCommand output', () {
      expect(
        betterRunnerOutput.toString(),
        stringContainsInOrder([
          _moMockText,
          upstreamRunnerOutput.toString(),
        ]),
      );
    });
    test('then Exit Code (null) matches that of upstream HelpCommand', () {
      expect(betterRunnerExitCode, equals(null));
      expect(betterRunnerExitCode, equals(upstreamRunnerExitCode));
    });
  });
}

void _testsForInvalidHelpUsageRequests(final List<String> args) {
  group('when $args is received', () {
    final betterRunnerOutput = StringBuffer();
    final upstreamRunnerOutput = StringBuffer();
    late final UsageException? betterRunnerException;
    late final UsageException? upstreamRunnerException;
    setUpAll(() async {
      try {
        await runZoned(
          () async => await _buildBetterRunner().run(args),
          zoneSpecification: ZoneSpecification(
            print: (final _, final __, final ___, final String line) {
              betterRunnerOutput.writeln(line);
            },
          ),
        );
      } on UsageException catch (e) {
        betterRunnerException = e;
      }
      try {
        await runZoned(
          () async => await _buildUpstreamRunner().run(args),
          zoneSpecification: ZoneSpecification(
            print: (final _, final __, final ___, final String line) {
              upstreamRunnerOutput.writeln(line);
            },
          ),
        );
      } on UsageException catch (e) {
        upstreamRunnerException = e;
      }
    });
    test('then it throws UsageException exactly like CommandRunner', () {
      expect(betterRunnerException, isA<UsageException>());
      expect(upstreamRunnerException, isA<UsageException>());
      expect(
        betterRunnerException!.message,
        equals(upstreamRunnerException!.message),
      );
      expect(
        betterRunnerException!.usage,
        equals(upstreamRunnerException!.usage),
      );
    });
    test('then MessageOutput is not bypassed', () {
      expect(
        betterRunnerOutput.toString(),
        stringContainsInOrder(
          [
            _moExceptionText,
            betterRunnerException!.message,
            betterRunnerException!.usage,
          ],
        ),
      );
    });
    test('then it can subsume upstream HelpCommand output', () {
      expect(
        betterRunnerOutput.toString(),
        contains(upstreamRunnerOutput.toString()),
      );
    });
  });
}
