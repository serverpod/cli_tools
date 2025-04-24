import 'package:cli_tools/better_command_runner.dart';
import 'package:test/test.dart';

class MockCommand extends BetterCommand {
  static String commandName = 'mock-command';

  MockCommand({super.messageOutput}) {
    argParser.addOption(
      'name',
      defaultsTo: 'serverpod',
      allowed: <String>['serverpod', 'stockholm'],
    );
  }

  @override
  String get description => 'Mock command used for testing';

  @override
  String get name => commandName;

  @override
  void run() {}
}

void main() {
  group('Given a better command registered in the better command runner', () {
    var infos = <String>[];
    var betterCommand = MockCommand(
      messageOutput: MessageOutput(
        logUsage: (u) => infos.add(u),
      ),
    );
    var runner = BetterCommandRunner('test', 'test project')
      ..addCommand(betterCommand);

    test(
      'when running command option --help flag then usage is printed to commands logInfo',
      () async {
        await runner.run([MockCommand.commandName, '--help']);

        expect(infos, hasLength(1));
        expect(infos.first, betterCommand.usage);
      },
    );
  });
}
