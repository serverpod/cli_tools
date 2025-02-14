import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_tools/better_command_runner.dart';

abstract class BetterCommand extends Command {
  final PassMessage? _logInfo;
  final ArgParser _argParser;

  BetterCommand({PassMessage? logInfo, int? wrapTextColumn})
    : _logInfo = logInfo,
      _argParser = ArgParser(usageLineLength: wrapTextColumn);

  @override
  ArgParser get argParser => _argParser;

  @override
  void printUsage() {
    _logInfo?.call(usage);
  }
}
