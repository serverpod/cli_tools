import 'abstract_command.dart' show AbstractCommand;
import 'usage/usage.dart' show commandUsage;

/// A command usage string generator.
abstract interface class UsageGenerator {
  /// Generates a formatted usage string for a command.
  String generate(final AbstractCommand command);
}

class StandardRunnerUsageGenerator implements UsageGenerator {
  const StandardRunnerUsageGenerator();

  @override
  String generate(final AbstractCommand command) {
    final lineLength = _getUsageLineLength(command);
    return commandUsage(command, false, lineLength);
  }
}

class StandardCommandUsageGenerator implements UsageGenerator {
  const StandardCommandUsageGenerator();

  @override
  String generate(final AbstractCommand command) {
    final lineLength = _getUsageLineLength(command);
    return commandUsage(command, true, lineLength);
  }
}

int? _getUsageLineLength(AbstractCommand command) {
  int? lineLength = command.usageLineLength;
  while (lineLength == null && command.hasParent) {
    command = command.parent;
    lineLength = command.usageLineLength;
  }
  return lineLength;
}
