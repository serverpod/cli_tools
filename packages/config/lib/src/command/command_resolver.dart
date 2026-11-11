import '../config/arg_parser/arg_parser.dart'
    show
        ArgParseResult,
        DoubleDashHandling,
        ParserSettings,
        scanAndParseCommands;
import '../config/config.dart'
    show
        CommandDefinition,
        OptionDefinition,
        UsageException,
        CommandUsageException;
import '../config/output_formatting.dart' show formatConfigError;
import 'abstract_command.dart';
import 'command_context.dart';
import 'command_runner.dart' show CommandRunner, builtinActionOptionSpecified;
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
  /// When [allowIncomplete] is true, those errors are left on the contexts
  /// and no exception is thrown. Completion uses this for a command line
  /// that is not finished. [runMode] is recorded on every context in the chain.
  CommandContext<O, T> resolveConfigurations(
    final Iterable<String> args,
    final Map<String, String>? env,
    final ContextProvider provider, {
    final bool allowIncomplete = false,
    final CommandRunMode runMode = CommandRunMode.execution,
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
    final bool allowIncomplete = false,
    final CommandRunMode runMode = CommandRunMode.execution,
  }) {
    final argParseResult = scanAndParseCommands(
      args,
      rootCommand: runner,
      settings: ParserSettings(
        doubleDashHandling: runner.ignoreUnexpectedPositionalArgs
            ? DoubleDashHandling.passThroughRest
            : DoubleDashHandling.noSpecialHandling,
        suggestionDistanceLimit: runner.suggestionDistanceLimit,
      ),
    );

    final contextChain = resolveNext(
      argParseResult,
      env,
      provider,
      null,
      runMode: runMode,
    );

    final CommandContext<O, T> contexts = contextChain as CommandContext<O, T>;

    // Completion resolves a partial command line. Errors stay on the
    // contexts for middleware and completion to inspect.
    if (allowIncomplete) return contexts;

    // Fail-fast on built-in option errors; if no such errors then
    // the built-in action options (e.g. --help, --completion)
    // act on the command line as given - no other errors are raised.
    if (_hasBuiltinOptionErrors(contexts)) {
      throwIfConfigurationErrors(contexts);
    } else if (builtinActionOptionSpecified(contexts)) {
      return contexts;
    }

    if (contexts.leaf().command.acceptsPartialCommandLine) {
      throwIfParseErrors(argParseResult);
      return contexts;
    }

    throwIfConfigurationErrors(contexts);

    return contexts;
  }

  CommandContext<OptionDefinition, T> resolveNext(
    final ArgParseResult<OptionDefinition> argParseResult,
    final Map<String, String>? env,
    final ContextProvider provider,
    final CommandContext<OptionDefinition, T>? prevContext, {
    final CommandRunMode runMode = CommandRunMode.execution,
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
  ) {
    final commandErrors = <(CommandDefinition, Iterable<String>)>[];
    CommandContext? context = contexts;
    while (context != null) {
      commandErrors.add((
        context.command,
        context.config.errors.followedBy(context.builtinConfig.errors),
      ));
      context = context.next;
    }
    _throwIfErrors(commandErrors);
  }

  bool _hasBuiltinOptionErrors(final CommandContext contexts) {
    for (CommandContext? c = contexts; c != null; c = c.next) {
      if (c.builtinConfig.errors.isNotEmpty) return true;
    }
    return false;
  }

  /// Throws a [CommandUsageException] if the command line could not be
  /// parsed, e.g. due to an unknown option or subcommand.
  ///
  /// Configuration errors such as missing mandatory options or invalid
  /// values are not considered. This is the validation for commands that
  /// accept a partial command line, see
  /// [AbstractCommand.acceptsPartialCommandLine].
  void throwIfParseErrors(final ArgParseResult argParseResult) {
    _throwIfErrors([
      for (final result in argParseResult.toList())
        if (result.command case final CommandDefinition command)
          (command, result.errors),
    ]);
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
