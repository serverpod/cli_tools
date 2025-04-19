import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_tools/better_command_runner.dart';

abstract class BetterCommand extends Command {
  final MessageOutput? _messageOutput;
  final ArgParser _argParser;

  BetterCommand({MessageOutput? messageOutput, int? wrapTextColumn})
      : _messageOutput = messageOutput,
        _argParser = ArgParser(usageLineLength: wrapTextColumn);

  @override
  ArgParser get argParser => _argParser;

  @override
  void printUsage() {
    _messageOutput?.logUsage(usage);
  }
}
