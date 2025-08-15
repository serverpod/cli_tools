import 'package:args/command_runner.dart';
import 'package:cli_tools/better_command_runner.dart';
import 'package:config/config.dart' show OptionDefinition;
import 'package:test/test.dart';

class MockCommand extends Command<void> {
  static String commandName = 'mock-command';

  @override
  String get description => 'Mock command used for testing';

  @override
  void run() {}

  MockCommand() {
    argParser.addOption(
      'name',
      // To make an option truly mandatory, you need to set mandatory to true.
      // and also define a callback.
      mandatory: true,
      callback: (final name) {},
      allowed: <String>['serverpod'],
    );
  }

  @override
  String get name => commandName;
}

void main() {
  group('Given runner with registered command', () {
    final runner = BetterCommandRunner<OptionDefinition<Object>, void>(
      'test',
      'this is a test cli',
    )..addCommand(MockCommand());

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
