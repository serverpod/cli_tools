import 'dart:io' show IOSink, exit;

import '../../config/config.dart'
    show
        CommandAliasesDefinition,
        CommandUsageDefinition,
        EnumOption,
        EnumParser,
        OptionDefinition;
import '../command.dart' show Command;
import '../command_context.dart' show CommandContext;
import '../command_runner.dart' show CommandRunner;
import 'completion_shell.dart';

/// The built-in `completion <shell>` command, which prints the completion
/// script for a shell to the usage output sink.
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

  @override
  final String name = 'completion';

  @override
  final CommandAliasesDefinition aliases = const CommandAliasesDefinition();

  final bool _hidden;

  CompletionCommand({final bool hidden = false})
    : _hidden = hidden,
      super(options: const [shellOption]);

  @override
  CommandUsageDefinition get usageDefinition => CommandUsageDefinition(
    description:
        'Generate a shell completion script.\n\n'
        'The script needs to be installed only once: it asks '
        '$_executableName for the completion alternatives, so it keeps '
        'working after $_executableName is updated.\n\n'
        '${completionInstallationOverview(_executableName)}',
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
    await printCompletionScript(root, context.config.value(shellOption));
    return null;
  }
}

/// Writes the completion script of [shell] for [runner] to the usage output,
/// see [writeCompletionOutput].
Future<void> printCompletionScript(
  final CommandRunner runner,
  final CompletionShell shell,
) {
  return writeCompletionOutput(
    runner,
    shell.script(
      runner.executableName,
      description: runner.usageDefinition.description,
    ),
  );
}

/// Writes the completion [output] (a response or a script) to the usage
/// output sink of [runner].
///
/// Unless disabled by `CompletionSettings.exitAfterResponse`, the sink is
/// then flushed and the process exits with exit code 0, so that nothing the
/// program does after `CommandRunner.runner()` can corrupt the output.
Future<void> writeCompletionOutput(
  final CommandRunner runner,
  final String output,
) async {
  final sink = runner.usageOutput.sinks.out;
  sink.write(output);
  if (!runner.completion.exitAfterResponse) return;
  if (sink is IOSink) await sink.flush();
  exit(0);
}
