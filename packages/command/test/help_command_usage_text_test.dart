import 'dart:async' show ZoneSpecification, runZoned;

import 'package:command/command.dart'
    show NewCommandRunner, MessageOutput, UsageException;
import 'package:test/test.dart';

void main() => _runTests();

const _exeName = 'mock';
const _exeDescription = 'A mock command to test `help -h` with MessageOutput.';
const _moMockText = 'SUCCESS: `MessageOutput.usageLogger`';
const _moExceptionText = 'SUCCESS: `MessageOutput.usageExceptionLogger`';
const _invalidOption = '-z';

NewCommandRunner _buildUpstreamRunner() => NewCommandRunner(
  _exeName,
  _exeDescription,
);

NewCommandRunner _buildNewRunner() => NewCommandRunner(
  _exeName,
  _exeDescription,
  messageOutput: MessageOutput(
    usageLogger: (usage) {
      print(_moMockText);
      print(usage);
    },
    usageExceptionLogger: (exception) {
      print(_moExceptionText);
      print(exception.message);
      print(exception.usage);
    },
  ),
);

void _runTests() {
  group('Given a NewCommandRunner with custom MessageOutput', () {
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

void _testsForValidHelpUsageRequests(List<String> args) {
  group('when $args is received', () {
    final commandRunnerOutput = StringBuffer();
    final upstreamRunnerOutput = StringBuffer();
    late final Object? commandRunnerExitCode;
    late final Object? upstreamRunnerExitCode;
    setUpAll(() async {
      commandRunnerExitCode = await runZoned(
        () async => await _buildNewRunner().run(args),
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, String line) {
            commandRunnerOutput.writeln(line);
          },
        ),
      );
      upstreamRunnerExitCode = await runZoned(
        () async => await _buildUpstreamRunner().run(args),
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, String line) {
            upstreamRunnerOutput.writeln(line);
          },
        ),
      );
    });
    test('then MessageOutput is not bypassed', () {
      expect(
        commandRunnerOutput.toString(),
        contains(_moMockText),
      );
    });
    test('then it can subsume upstream HelpCommand output', () {
      expect(
        commandRunnerOutput.toString(),
        stringContainsInOrder([
          _moMockText,
          upstreamRunnerOutput.toString(),
        ]),
      );
    });
    test('then Exit Code (null) matches that of upstream HelpCommand', () {
      expect(commandRunnerExitCode, equals(null));
      expect(commandRunnerExitCode, equals(upstreamRunnerExitCode));
    });
  });
}

void _testsForInvalidHelpUsageRequests(List<String> args) {
  group('when $args is received', () {
    final commandRunnerOutput = StringBuffer();
    final upstreamRunnerOutput = StringBuffer();
    UsageException? commandRunnerException;
    UsageException? upstreamRunnerException;
    setUpAll(() async {
      try {
        await runZoned(
          () async => await _buildNewRunner().run(args),
          zoneSpecification: ZoneSpecification(
            print: (_, _, _, String line) {
              commandRunnerOutput.writeln(line);
            },
          ),
        );
      } on UsageException catch (e) {
        commandRunnerException = e;
      }
      try {
        await runZoned(
          () async => await _buildUpstreamRunner().run(args),
          zoneSpecification: ZoneSpecification(
            print: (_, _, _, String line) {
              upstreamRunnerOutput.writeln(line);
            },
          ),
        );
      } on UsageException catch (e) {
        upstreamRunnerException = e;
      }
    });
    test('then it throws UsageException exactly like CommandRunner', () {
      expect(commandRunnerException, isA<UsageException>());
      expect(upstreamRunnerException, isA<UsageException>());
      expect(
        commandRunnerException!.message,
        equals(upstreamRunnerException!.message),
      );
      expect(
        commandRunnerException!.usage,
        equals(upstreamRunnerException!.usage),
      );
    });
    test('then MessageOutput is not bypassed', () {
      expect(
        commandRunnerOutput.toString(),
        stringContainsInOrder(
          [
            _moExceptionText,
            commandRunnerException!.message,
            commandRunnerException!.usage,
          ],
        ),
      );
    });
    test('then it can subsume upstream HelpCommand output', () {
      expect(
        commandRunnerOutput.toString(),
        contains(upstreamRunnerOutput.toString()),
      );
    });
  });
}
