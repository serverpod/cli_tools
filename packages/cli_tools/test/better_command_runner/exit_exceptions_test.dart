import 'dart:async' show FutureOr;

import 'package:cli_tools/better_command_runner.dart'
    show BetterCommand, BetterCommandRunner, UsageException, RunContext;
import 'package:config/config.dart' show StringOption;
import 'package:test/test.dart';

class MockCommand extends BetterCommand {
  static String commandName = 'mock-command';

  @override
  String get description => 'Mock command used for testing';

  @override
  FutureOr? run(final RunContext runContext) {
    return null;
  }

  MockCommand()
      : super(options: [
          const StringOption(
            argName: 'name',
            mandatory: true,
            allowedValues: ['serverpod'],
          )
        ]);

  @override
  String get name => commandName;
}

void main() {
  group('Given runner with registered command', () {
    final runner = BetterCommandRunner('test', 'this is a test cli')
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
