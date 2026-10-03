import 'dart:async' show FutureOr;

import 'package:command/command.dart'
    show NewCommand, NewCommandRunner, UsageException, RunContext;
import 'package:config/config.dart' show StringOption;
import 'package:test/test.dart';

class MockCommand extends NewCommand {
  static String commandName = 'mock-command';

  @override
  String get description => 'Mock command used for testing';

  @override
  FutureOr? run(RunContext runContext) {
    return null;
  }

  MockCommand()
    : super(
        options: [
          const StringOption(
            argName: 'name',
            mandatory: true,
            allowedValues: ['serverpod'],
          ),
        ],
      );

  @override
  String get name => commandName;
}

void main() {
  group('Given runner with registered command', () {
    final runner = NewCommandRunner('test', 'this is a test cli')
      ..addCommand(MockCommand());

    test(
      'when running with unknown command then UsageException is thrown.',
      () async {
        final args = ['unknown-command'];

        await expectLater(
          runner.run(args),
          throwsA(isA<UsageException>()),
        );
      },
    );

    test(
      'when running with invalid command then UsageException is thrown.',
      () async {
        final List<String> args = ['this it not a valid command'];

        await expectLater(
          runner.run(args),
          throwsA(isA<UsageException>()),
        );
      },
    );

    test(
      'when running command without mandatory option then UsageException is thrown.',
      () async {
        final List<String> args = [MockCommand.commandName];

        await expectLater(
          runner.run(args),
          throwsA(isA<UsageException>()),
        );
      },
    );
  });
}
