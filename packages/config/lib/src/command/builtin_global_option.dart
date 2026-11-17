import 'dart:async' show FutureOr;

import '../../config.dart'
    show ConfigOptionBase, EnumOption, EnumParser, FlagOption, OptionDefinition;
import 'action_option.dart';
import 'command_context.dart';
import 'completion/completion.dart' show printCompletionScript;
import 'completion/completion_shell.dart' show CompletionShell;
import 'help_command.dart' show printCommandUsage;

/// The built-in global options of a command runner,
/// see `CommandRunner.builtinPersistentOptions`.
enum BuiltinGlobalOption<V extends Object> implements OptionDefinition<V> {
  /// Shows the usage of the last command on the command line.
  help(HelpActionOption()),

  /// `--completion <shell>`: prints the completion script for the shell.
  completion(CompletionActionOption());

  const BuiltinGlobalOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

class HelpActionOption extends FlagOption with ActionOptionMixin<bool> {
  const HelpActionOption()
    : super(
        argName: 'help',
        argAbbrev: 'h',
        negatable: false,
        helpText: 'Print this usage information.',
      );

  @override
  FutureOr<R?> run<O extends OptionDefinition, R>(
    final CommandContext<O, R> context,
  ) {
    printCommandUsage(context.leaf());
    return null;
  }
}

class CompletionActionOption extends EnumOption<CompletionShell>
    with ActionOptionMixin<CompletionShell> {
  const CompletionActionOption()
    : super(
        enumParser: const EnumParser(CompletionShell.values),
        argName: 'completion',
        helpText: 'Print the shell completion script for the shell.',
      );

  @override
  FutureOr<R?> run<O extends OptionDefinition, R>(
    final CommandContext<O, R> context,
  ) {
    final completionShell = context.builtinConfig.optionalValue(
      BuiltinGlobalOption.completion,
    );
    if (completionShell == null) {
      throw StateError('Completion shell value is null');
    }
    // (Exits the process after writing the script if
    // CompletionSettings.exitAfterResponse is true.)
    return printCompletionScript(
      context.command.runner,
      completionShell,
    ).then((final _) => null);
  }
}
