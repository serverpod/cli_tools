import 'dart:io' show IOSink, exit;

import '../../config/config.dart'
    show
        CommandUsageDefinition,
        CommandUsageException,
        ConfigOptionBase,
        Configuration,
        EnumOption,
        EnumParser,
        FlagOption,
        OptionDefinition,
        StringOption;
import '../command.dart' show Command;
import '../command_context.dart' show CommandContext;
import '../command_runner.dart' show CommandRunner;
import 'completion_installer.dart';
import 'completion_shell.dart';
import 'completion_shell_detection.dart';

/// The options of the [CompletionCommand]. They are persistent,
/// i.e. also valid after its `install` subcommand.
enum CompletionOption<V extends Object> implements OptionDefinition<V> {
  /// The shell to generate the script for. When not given, it is the shell
  /// the command is most likely run from, see [detectCompletionShell].
  shell(
    EnumOption<CompletionShell>(
      enumParser: EnumParser(CompletionShell.values),
      argName: 'shell',
      fromCustom: _detectShell,
      helpText:
          'The shell to generate the completion script for. '
          'Detected from the shell the command is run from if not given.',
    ),
  ),

  /// The command name to complete instead of the executable name,
  /// for a wrapper script of the executable.
  command(
    StringOption(
      argName: 'command',
      helpText:
          'Complete this command name instead, e.g. a wrapper script '
          'that forwards to the executable with the same commands and options. '
          'The completion requests are sent to the executable directly.',
    ),
  );

  const CompletionOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

/// The custom value provider of [CompletionOption.shell].
CompletionShell? _detectShell(final Configuration _) => detectCompletionShell();

/// The options of the [CompletionInstallCommand].
enum CompletionInstallOption<V extends Object> implements OptionDefinition<V> {
  /// Prints the steps of the installation without performing them.
  dryRun(
    FlagOption(
      argName: 'dry-run',
      negatable: false,
      defaultsTo: false,
      helpText: 'Print what the installation does without doing it.',
    ),
  );

  const CompletionInstallOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

/// The built-in `completion` command, which prints the completion script
/// for a shell to [CompletionSettings.sinks]. Its `install` subcommand,
/// [CompletionInstallCommand], installs the script instead.
///
/// Automatically added as a subcommand of a [CommandRunner] that has
/// subcommands, unless disabled via `CompletionSettings` or a subcommand
/// named `completion` is defined.
class CompletionCommand<T> extends Command<CompletionOption, T> {
  @override
  final String name = 'completion';

  final bool _hidden;

  /// [installer] performs the installations of the `install` subcommand.
  /// By default the script is installed for the current user and platform.
  CompletionCommand({
    final bool hidden = false,
    final CompletionInstaller? installer,
  }) : _hidden = hidden,
       super(
         persistentOptions: CompletionOption.values,
         subcommands: [CompletionInstallCommand<T>(installer: installer)],
         canRunAsLeafCommand: true,
       );

  @override
  CommandUsageDefinition get usageDefinition => CommandUsageDefinition(
    description:
        'Generate a shell completion script.\n\n'
        'The script needs to be installed only once: it asks '
        '$_executableName for the completion alternatives, so it keeps '
        'up automatically when $_executableName is updated.\n\n'
        'To install it, run `$_executableName completion install`.\n\n'
        '${completionInstallationOverview(_executableName, heading: 'Manual installation:')}\n\n'
        'For a wrapper script with name <name>, generate or install '
        'the script with `--command <name>`.',
    hidden: _hidden,
  );

  String get _executableName => hasParent ? parent.name : '<executable>';

  @override
  Future<T?> run(final CommandContext<CompletionOption, T> context) async {
    final request = _CompletionRequest.of(context);
    if (request == null) return null;
    await writeCompletionOutput(request.runner, request.script);
    return null;
  }
}

/// The `completion install` command, which installs the completion script
/// for the current user with a [CompletionInstaller], and prints the steps
/// of the installation to [CompletionSettings.sinks].
///
/// The shell and the command name to complete are given by the persistent
/// options of its parent, the [CompletionCommand].
class CompletionInstallCommand<T> extends Command<CompletionInstallOption, T> {
  @override
  final String name = 'install';

  final CompletionInstaller? _installer;

  CompletionInstallCommand({final CompletionInstaller? installer})
    : _installer = installer,
      super(
        options: CompletionInstallOption.values,
        usageDefinition: const CommandUsageDefinition(
          description:
              'Install the shell completion script for the current user.\n\n'
              'Prints the changes it makes: the script is saved where the '
              'shell (or bash-completion, or Carapace) looks for it, and '
              'for Bash, Zsh and PowerShell a line that loads it is added '
              'to the startup file of the shell. Installing again updates '
              'the script.',
        ),
      );

  @override
  Future<T?> run(
    final CommandContext<CompletionInstallOption, T> context,
  ) async {
    final request = _CompletionRequest.of(context);
    if (request == null) return null;
    final dryRun = context.config.value(CompletionInstallOption.dryRun);

    // The script is saved in a file named after the command: a path
    // would name a file elsewhere.
    final commandName = request.commandName;
    if (commandName != null &&
        !CompletionInstaller.isCommandName(commandName)) {
      _reportUsageError(
        context,
        'Cannot install the completion for "$commandName". '
        'Specify the name of the command with --command, not its path.',
      );
      return null;
    }

    final steps = (_installer ?? CompletionInstaller()).plan(
      request.shell,
      name: request.name,
      script: request.script,
      executableName: request.runner.executableName,
    );

    final out = request.runner.completion.sinks.out;
    out.writeln(
      'Installing the ${request.shell.displayName} completion '
      'for ${request.name}${dryRun ? ' (dry run, nothing is changed)' : ''}:',
    );
    for (final step in steps) {
      out.writeln('  ${step.description.replaceAll('\n', '\n  ')}');
      if (!dryRun) step.perform();
    }
    if (!dryRun) out.writeln(request.shell.activationInstruction);
    return null;
  }
}

/// What a `completion` command line asks for: the completion script of
/// [shell] for the command [name] of [runner].
class _CompletionRequest {
  final CommandRunner runner;
  final CompletionShell shell;

  /// The command name to complete instead of the executable name, if any.
  final String? commandName;

  _CompletionRequest(this.runner, this.shell, this.commandName);

  String get name => commandName ?? runner.executableName;

  String get script => shell.script(
    runner.executableName,
    description: runner.usageDefinition.description,
    viaOption: runner.subcommands.isEmpty,
    commandName: commandName,
  );

  /// The request of the command line that ends with [context], whose
  /// [CompletionOption]s are those of the [CompletionCommand] on it.
  ///
  /// If the shell is neither given nor detected, a usage error is reported
  /// for the command of [context]. Returns null if the usage output
  /// settings of the runner suppress the exception.
  static _CompletionRequest? of<T>(
    final CommandContext<OptionDefinition, T> context,
  ) {
    final runner = context.command.runner;
    CommandContext<OptionDefinition, T>? completion = context;
    while (completion != null && completion.command is! CompletionCommand) {
      completion = completion.prev;
    }
    if (completion == null) {
      throw StateError(
        'The ${context.command.name} command requires a CompletionCommand '
        'before it on the command line.',
      );
    }

    final config = completion.config;
    final shell = config.optionalValue(CompletionOption.shell);
    if (shell == null) {
      _reportUsageError(
        context,
        'Could not detect the shell. Specify it with --shell.',
      );
      return null;
    }
    return _CompletionRequest(
      runner,
      shell,
      config.optionalValue(CompletionOption.command),
    );
  }
}

/// Reports the usage error [message] for the command of [context].
/// Returns if the usage output settings of the runner suppress the
/// exception.
void _reportUsageError<T>(
  final CommandContext<OptionDefinition, T> context,
  final String message,
) {
  final command = context.command;
  final exception = command.runner.usageOutput.onUsageException(
    CommandUsageException('${command.name}: $message', command),
    fromCommand: command,
  );
  if (exception != null) throw exception;
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
    _CompletionRequest(runner, shell, commandName).script,
  );
}

/// Writes the completion [output] (a response or a script) to
/// [CompletionSettings.sinks].
///
/// The usage output sinks are not used. They are for help text, and may
/// reformat what they write.
///
/// If `CompletionSettings.exitAfterResponse` is set, the output is then
/// flushed and the process exits with exit code 0, so that nothing the
/// program does after `CommandRunner.run()` can corrupt the output.
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
