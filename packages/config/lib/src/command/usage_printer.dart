import '../config/config.dart' show CommandDefinition;

abstract interface class UsagePrinter {
  void print(final CommandDefinition command, final StringSink sink);
}

class StandardUsagePrinter implements UsagePrinter {
  const StandardUsagePrinter();

  /// Placeholder until command usage text is generated.
  @override
  void print(final CommandDefinition command, final StringSink sink) {
    sink.writeln('Command: ${command.name}');
    sink.writeln('Description: ${command.usage.description}');
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
