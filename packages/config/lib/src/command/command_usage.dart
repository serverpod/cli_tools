import '../config/config.dart' show CommandDefinition;

abstract interface class CommandUsagePrinter {
  void print(final CommandDefinition command, final StringSink out);
}

class DefaultCommandUsagePrinter implements CommandUsagePrinter {
  const DefaultCommandUsagePrinter();

  /// Placeholder until command usage text is generated.
  @override
  void print(final CommandDefinition command, final StringSink out) {
    out.writeln('Command: ${command.name}');
    out.writeln('Description: ${command.usage.description}');
    if (command.aliases.aliases.isNotEmpty) {
      out.writeln('Aliases: ${command.aliases.aliases.join(', ')}');
    }
    if (command.subcommands.isNotEmpty) {
      out.writeln('Subcommands:');
      for (final subcommand in command.subcommands) {
        out.writeln('  ${subcommand.name}');
      }
    }
    final argNameOptions = command.options.where(
      (final option) => option.option.argName != null,
    );
    if (argNameOptions.isNotEmpty) {
      out.writeln('Named options:');
      for (final option in argNameOptions) {
        if (option.option.argAbbrev != null) {
          out.writeln(
            '  ${option.option.argName} / ${option.option.argAbbrev}',
          );
        } else {
          out.writeln('  ${option.option.argName}');
        }
      }
    }
    final argPosOptions = command.options.where(
      (final option) => option.option.argPos != null,
    );
    if (argPosOptions.isNotEmpty) {
      out.writeln('Positional Options:');
      for (final option in argPosOptions) {
        out.writeln('  ${option.option.argPos}');
      }
    }
  }
}
