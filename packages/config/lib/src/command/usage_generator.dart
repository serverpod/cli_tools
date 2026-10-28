import 'abstract_command.dart' show AbstractCommand;
import 'usage/usage.dart' show commandUsage;

abstract interface class UsageGenerator {
  String generate(final AbstractCommand command);
}

class PlaceHolderUsageGenerator implements UsageGenerator {
  const PlaceHolderUsageGenerator();

  /// Placeholder until command usage text is generated.
  @override
  String generate(final AbstractCommand command) {
    final StringBuffer buffer = StringBuffer();
    _tmpPrint(command, buffer);
    return buffer.toString();
  }

  void _tmpPrint(final AbstractCommand command, final StringSink sink) {
    sink.writeln('Command: ${command.name}');
    sink.writeln('Description: ${command.usageDefinition.description}');
    if (command.aliases.aliases.isNotEmpty) {
      sink.writeln('Aliases: ${command.aliases.aliases.join(', ')}');
    }
    if (command.subcommands.isNotEmpty) {
      sink.writeln('Subcommands:');
      for (final subcommand in command.subcommands) {
        sink.writeln('  ${subcommand.name}');
      }
    }
    final argNameOptions = command.options.where(
      (final option) => option.option.argName != null,
    );
    if (argNameOptions.isNotEmpty) {
      sink.writeln('Named options:');
      for (final option in argNameOptions) {
        if (option.option.argAbbrev != null) {
          sink.writeln(
            '  ${option.option.argName} / ${option.option.argAbbrev}',
          );
        } else {
          sink.writeln('  ${option.option.argName}');
        }
      }
    }
    final argPosOptions = command.options.where(
      (final option) => option.option.argPos != null,
    );
    if (argPosOptions.isNotEmpty) {
      sink.writeln('Positional Options:');
      for (final option in argPosOptions) {
        sink.writeln('  ${option.option.argPos}');
      }
    }
  }
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
