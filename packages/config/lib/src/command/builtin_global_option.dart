import '../config/config.dart'
    show ConfigOptionBase, EnumOption, EnumParser, FlagOption, OptionDefinition;
import 'completion/completion_shell.dart' show CompletionShell;

/// The built-in global options of a command runner,
/// see `CommandRunner.builtinPersistentOptions`.
enum BuiltinGlobalOption<V extends Object> implements OptionDefinition<V> {
  /// Shows the usage of the last command on the command line.
  help(
    FlagOption(
      argName: 'help',
      argAbbrev: 'h',
      defaultsTo: false,
      negatable: false,
      helpText: 'Show the usage help for a command.',
    ),
  ),

  /// `--completion <shell>`: prints the completion script for the shell.
  completion(
    EnumOption<CompletionShell>(
      enumParser: EnumParser(CompletionShell.values),
      argName: 'completion',
      helpText: 'Print the shell completion script for the shell.',
      allowedValues: CompletionShell.values,
    ),
  );

  const BuiltinGlobalOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}
