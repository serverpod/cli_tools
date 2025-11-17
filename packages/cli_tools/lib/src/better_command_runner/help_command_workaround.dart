import 'package:args/args.dart' show ArgResults;
import 'package:args/command_runner.dart' show Command, CommandRunner;

/// A dummy to replicate the usage-text of upstream private `HelpCommand`.
///
/// It is intended to be used for an internal patch only and is
/// intentionally not part of the public API of this package.
final class HelpCommandWorkaround extends Command {
  HelpCommandWorkaround({required this.runner});

  /// Checks whether the main command seeks the
  /// usage-text for `help` command.
  ///
  /// Specifically, for a program `mock`, it checks
  /// whether [topLevelResults] is of the form:
  /// * `mock help -h`
  /// * `mock help help`
  bool isUsageOfHelpCommandRequested(final ArgResults topLevelResults) {
    // check whether `help` command is chosen
    final topLevelCommand = topLevelResults.command;
    if (topLevelCommand == null) {
      return false;
    }
    if (topLevelCommand.name != name) {
      return false;
    }
    final helpCommand = topLevelCommand;
    // check whether it's allowed to get the usage-text for `help`
    if (!helpCommand.options.contains(name)) {
      // extremely rare scenario (e.g. if `package:args` has a breaking change)
      // fortunately, corresponding test-cases shall fail as it
      // - tests the current behavior (e.g. args = ['help', '-h'])
      // - notifies the publisher(s) of this breaking change
      return false;
    }
    // case: `mock help -h`
    if (helpCommand.flag(name)) {
      return true;
    }
    // case: `mock help help`
    if ((helpCommand.arguments.contains(name))) {
      return true;
    }
    // aside: more cases may be added if necessary in future
    return false;
  }

  @override
  final CommandRunner runner;

  @override
  final name = 'help';

  @override
  String get description =>
      'Display help information for ${runner.executableName}.';

  @override
  String get invocation => '${runner.executableName} $name [command]';

  @override
  Never run() => throw UnimplementedError(
      'This class is meant to only obtain the Usage Text for `$name` command');
}
