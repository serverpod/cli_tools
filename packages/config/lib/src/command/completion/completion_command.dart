import 'dart:io' show IOSink, exit;

import '../../config/config.dart'
    show
        CommandUsageDefinition,
        EnumOption,
        EnumParser,
        OptionDefinition,
        StringOption;
import '../command.dart' show Command;
import '../command_context.dart' show CommandContext;
import '../command_runner.dart' show CommandRunner;
import 'completion_shell.dart';

/// The built-in `completion <shell>` command, which prints the completion
/// script for a shell to [CompletionSettings.sinks].
///
/// Automatically added as a subcommand of a [CommandRunner] that has
/// subcommands, unless disabled via `CompletionSettings` or a subcommand
/// named `completion` is defined.
///
/// Like `help`, it runs standalone: the middlewares of the parent commands
/// are bypassed so that nothing else is written to the output.
class CompletionCommand<T> extends Command<OptionDefinition, T> {
  /// The shell to generate the script for, as a positional argument.
  static const EnumOption<CompletionShell> shellOption =
      EnumOption<CompletionShell>(
        enumParser: EnumParser(CompletionShell.values),
        argName: 'shell',
        argPos: 0,
        mandatory: true,
        helpText: 'The shell to generate the completion script for.',
      );

  /// The command name to complete instead of the executable name,
  /// for a wrapper script of the executable.
  static const StringOption commandOption = StringOption(
    argName: 'command',
    helpText:
        'Complete this command name instead, e.g. a wrapper script '
        'that forwards to the executable with the same commands and options. '
        'The completion requests are sent to the executable directly.',
  );

  @override
  final String name = 'completion';

  final bool _hidden;

  CompletionCommand({final bool hidden = false})
    : _hidden = hidden,
      super(options: const [shellOption, commandOption]);

  @override
  CommandUsageDefinition get usageDefinition => CommandUsageDefinition(
    description:
        'Generate a shell completion script.\n\n'
        'The script needs to be installed only once: it asks '
        '$_executableName for the completion alternatives, so it keeps '
        'working after $_executableName is updated.\n\n'
        '${completionInstallationOverview(_executableName)}\n\n'
        'For a wrapper script of $_executableName, generate the script '
        'with `--command <name>` and install it for that name instead.',
    hidden: _hidden,
  );

  String get _executableName => hasParent ? parent.name : '<executable>';

  @override
  bool get runStandalone => true;

  @override
  Future<T?> run(final CommandContext<OptionDefinition, T> context) async {
    final root = context.root().command;
    if (root is! CommandRunner<OptionDefinition, T>) {
      throw StateError(
        'The completion command requires the root command to be a '
        "CommandRunner but it's a ${root.runtimeType}.",
      );
    }
    await printCompletionScript(
      root,
      context.config.value(shellOption),
      commandName: context.config.optionalValue(commandOption),
    );
    return null;
  }
}

/// Writes the completion script of [shell] for [runner] to
/// [CompletionSettings.sinks]. See [writeCompletionOutput].
///
/// [commandName] generates the script for a wrapper of the executable
/// instead, see [CompletionShell.script].
Future<void> printCompletionScript(
  final CommandRunner runner,
  final CompletionShell shell, {
  final String? commandName,
}) {
  return writeCompletionOutput(
    runner,
    shell.script(
      runner.executableName,
      description: runner.usageDefinition.description,
      viaOption: runner.subcommands.isEmpty,
      commandName: commandName,
    ),
  );
}

/// Writes the completion [output] (a response or a script) to
/// [CompletionSettings.sinks].
///
/// The usage output sinks are not used. They are for help text, and may
/// reformat what they write.
///
/// Unless disabled by `CompletionSettings.exitAfterResponse`, the output is
/// then flushed and the process exits with exit code 0, so that nothing the
/// program does after `CommandRunner.runner()` can corrupt the output.
Future<void> writeCompletionOutput(
  final CommandRunner runner,
  final String output,
) async {
  final sink = runner.completion.sinks.out;
  sink.write(output);
  if (!runner.completion.exitAfterResponse) return;
  if (sink is IOSink) await sink.flush();
  exit(0);
}
