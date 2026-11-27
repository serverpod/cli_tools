import '../../config.dart'
    show
        ArgParseResult,
        scanAndParseCommands,
        subcommandRequiredErrorPrefix,
        CommandDefinition,
        OptionDefinition,
        UsageException,
        CommandUsageException,
        formatConfigError;
import 'abstract_command.dart';
import 'action_option.dart';
import 'command_context.dart';
import 'command_runner.dart' show CommandRunner;
import 'context_provider.dart';

/// Interface for the command resolver, which resolves the configurations for
/// each command on the command line.
///
/// Custom implementations of this interface can be used to change the
/// standard command resolution process.
abstract interface class CommandResolver<O extends OptionDefinition, T> {
  /// Resolves the configurations for each command on the command line.
  ///
  /// Returns the chain of resolved command contexts for the commands on the
  /// command line. The first context is for the root command, and has the same
  /// option type [O] as the runner.
  ///
  /// Throws [UsageException] on configuration input errors including
  /// command line arguments, environment variables, and configuration files.
  ///
  /// When [runMode] is [CommandRunMode.completion], those errors are left on
  /// the contexts and no exception is thrown, so a command line that is not
  /// finished can still be completed. [runMode] is recorded on every context
  /// in the chain.
  CommandContext<O, T> resolveConfigurations(
    final Iterable<String> args,
    final Map<String, String>? env,
    final ContextProvider provider, {
    required final CommandRunMode runMode,
  });
}

/// The standard command resolver.
class StandardCommandResolver<O extends OptionDefinition, T>
    implements CommandResolver<O, T> {
  /// The runner whose command tree and parser settings are resolved.
  final CommandRunner<O, T> runner;

  const StandardCommandResolver(this.runner);

  @override
  CommandContext<O, T> resolveConfigurations(
    final Iterable<String> args,
    final Map<String, String>? env,
    final ContextProvider provider, {
    required final CommandRunMode runMode,
  }) {
    final argParseResult = scanAndParseCommands(
      args,
      rootCommand: runner,
      settings: runner.parserSettings,
    );

    final contextChain = resolveNext(
      argParseResult,
      env,
      provider,
      null,
      runMode: runMode,
    );

    final CommandContext<O, T> contexts = contextChain as CommandContext<O, T>;

    throwIfConfigurationErrors(contexts, runMode);

    return contexts;
  }

  CommandContext<OptionDefinition, T> resolveNext(
    final ArgParseResult<OptionDefinition> argParseResult,
    final Map<String, String>? env,
    final ContextProvider provider,
    final CommandContext<OptionDefinition, T>? prevContext, {
    required final CommandRunMode runMode,
  }) {
    final command = argParseResult.command;
    if (command == null) throw StateError('ArgParseResult.command is null');
    if (command is! AbstractCommand<OptionDefinition, T>) {
      throw StateError(
        'ArgParseResult.command is not an AbstractCommand: ${command.runtimeType}',
      );
    }

    final context = command.resolveCmd(
      argParseResult,
      env,
      provider,
      prevContext,
      runMode: runMode,
    );

    if (argParseResult.child case final ArgParseResult child) {
      final nextContext = resolveNext(
        child,
        env,
        provider,
        context,
        runMode: runMode,
      );
      context.next = nextContext;
    } else {
      context.next = null;
    }

    return context;
  }

  /// Throws a [CommandUsageException] if any command on the command line
  /// has configuration errors, including command line parse errors.
  void throwIfConfigurationErrors(
    final CommandContext contexts,
    final CommandRunMode runMode,
  ) {
    // Completion mode: Resolves a partial command line. Errors stay on the
    // contexts for middleware and completion to inspect.
    if (runMode == CommandRunMode.completion) return;

    final acceptsPartialCommandLine = _acceptsPartialCommandLine(contexts);

    final commandErrors = <(CommandDefinition, Iterable<String>)>[];
    CommandContext? context = contexts;
    while (context != null) {
      final allErrors = context.config.errors.followedBy(
        context.builtinConfig.errors,
      );
      final errors = acceptsPartialCommandLine
          ? allErrors.where((final error) => !_isMissingValueError(error))
          : allErrors;
      commandErrors.add((context.command, errors));
      context = context.next;
    }
    _throwIfErrors(commandErrors);
  }

  /// Whether [error] reports a value that was never supplied.
  ///
  /// `Missing value for option` stays reportable: that option was written
  /// on the command line.
  bool _isMissingValueError(final String error) {
    if (error.startsWith(subcommandRequiredErrorPrefix)) return true;
    if (error.endsWith('is mandatory')) return true;
    if (error.endsWith('requires one of the options to be provided')) {
      return true;
    }
    return false;
  }

  bool _acceptsPartialCommandLine(final CommandContext contexts) {
    if (_specifiedActionOption(contexts)
        case final ActionOptionMixin actionOption) {
      return actionOption.acceptsPartialCommandLine;
    }

    if (contexts.leaf().command.acceptsPartialCommandLine) return true;

    return false;
  }

  void _throwIfErrors(
    final Iterable<(CommandDefinition, Iterable<String>)> commandErrors,
  ) {
    final messages = <String>[];
    CommandDefinition? firstCommandWithErrors;

    for (final (command, errors) in commandErrors) {
      if (errors.isEmpty) continue;
      messages.addAll(
        errors.map(
          (final error) => '${command.name}: ${formatConfigError(error)}',
        ),
      );
      firstCommandWithErrors ??= command;
    }

    if (firstCommandWithErrors != null) {
      throw CommandUsageException(messages.join('\n'), firstCommandWithErrors);
    }
  }
}

/// Returns the first of the action options that were specified on the command
/// line, or null if none.
ActionOptionMixin? _specifiedActionOption(final CommandContext contexts) {
  CommandContext? context = contexts;
  while (context != null) {
    final actionOption = context.specifiedActionOption;
    if (actionOption != null) return actionOption;
    context = context.next;
  }
  return null;
}
