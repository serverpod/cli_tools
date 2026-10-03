import 'dart:async';

import 'package:command/command.dart';
import 'package:config/config.dart' show StringOption;
import 'package:test/test.dart';

class MockCommand extends NewCommand {
  void Function()? onRun;
  static String commandName = 'mock-command';
  List<String> trackedOptions = [];
  int numberOfRuns = 0;

  @override
  String get description => 'Mock command used for testing';

  @override
  FutureOr? run(RunContext runContext) {
    final commandConfig = runContext.commandConfig;
    onRun?.call();
    trackedOptions.add(commandConfig.findValueOf(argName: 'name') as String);
    numberOfRuns++;
  }

  @override
  String get name => commandName;

  MockCommand({this.onRun})
    : super(
        options: [
          const StringOption(
            argName: 'name',
            defaultsTo: 'serverpod',
            allowedValues: ['serverpod', 'stockholm'],
          ),
        ],
      );
}

void main() {
  late NewCommandRunner runner;
  late MockCommand mockCommand;
  group('Given runner with registered command', () {
    setUp(() {
      mockCommand = MockCommand();
      runner = NewCommandRunner('test', 'this is a test cli')
        ..addCommand(mockCommand);
    });

    group('when running registered command with global flag', () {
      final args = [
        '--${NewCommandRunnerFlags.quiet}',
        MockCommand.commandName,
      ];
      setUp(() async => await runner.run(args));

      test('then command is run once', () {
        expect(mockCommand.numberOfRuns, equals(1));
      });
    });

    group('when running registered command without option', () {
      final args = [MockCommand.commandName];
      setUp(() async => await runner.run(args));

      test('then command is run once', () {
        expect(mockCommand.numberOfRuns, equals(1));
      });

      test('then default option is used in command', () {
        expect(mockCommand.trackedOptions, hasLength(1));
        expect(mockCommand.trackedOptions.first, equals('serverpod'));
      });
    });

    group('when running registered command and valid option', () {
      final args = [MockCommand.commandName, '--name', 'stockholm'];
      setUp(() async => await runner.run(args));

      test('then command is run once', () {
        expect(mockCommand.numberOfRuns, equals(1));
      });

      test('then provided option is used in command', () {
        expect(mockCommand.trackedOptions, hasLength(1));
        expect(mockCommand.trackedOptions.first, equals('stockholm'));
      });
    });

    test(
      'when running registered command with invalid option then command is never run.',
      () async {
        final args = [MockCommand.commandName, '--name', 'invalid'];

        try {
          await runner.run(args);
        } catch (_) {
          // ignore any exceptions.
        }
        expect(mockCommand.numberOfRuns, equals(0));
      },
    );
  });

  test(
    'Given runner with registered command and onBeforeRunCommand callback then onBeforeRunCommand is called before running command',
    () async {
      final List<String> calls = [];
      mockCommand = MockCommand(onRun: () => calls.add('command'));
      runner = NewCommandRunner(
        'test',
        'this is a test cli',
        onBeforeRunCommand: (_) => Future(() => calls.add('callback')),
      )..addCommand(mockCommand);

      final args = [MockCommand.commandName];

      await runner.run(args);
      expect(calls, equals(['callback', 'command']));
    },
  );
}
