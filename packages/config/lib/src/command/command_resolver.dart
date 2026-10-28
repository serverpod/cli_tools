import '../config/arg_parser/arg_parser.dart'
    show ArgParseResult, DoubleDashHandling, ScanMode, scanAndParseCommands;
import '../config/config.dart'
    show
        CommandDefinition,
        OptionDefinition,
        Configuration,
        UsageException,
        CommandUsageException,
        NewParsedArgs;
import '../config/output_formatting.dart' show formatConfigError;
import 'abstract_command.dart';
import 'command_context.dart';
import 'command_runner.dart' show CommandRunner, helpOptionSpecified;
import 'context_provider.dart';

/// Interface for the command resolver, which resolves the configurations for
/// each command on the command line.
///
/// Custom implementations of this interface can be used to change the
/// standard command resolution process.
abstract interface class CommandResolver<T> {
  /// Resolves the configurations for each command on the command line.
  ///
  /// Throws [UsageException] on configuration input errors including
  /// command line arguments, environment variables, and configuration files.
  CommandContext<OptionDefinition, T> resolveConfigurations(
    final Iterable<String> args,
    final Map<String, String>? env,
    final ContextProvider? provider, {
    required final CommandRunner<OptionDefinition, T> runner,
  });
}

/// The standard command resolver implementation.
class StandardCommandResolver<T> implements CommandResolver<T> {
  StandardCommandResolver();

  @override
  CommandContext<OptionDefinition, T> resolveConfigurations(
    final Iterable<String> args,
    final Map<String, String>? env,
    final ContextProvider? provider, {
    required final CommandRunner<OptionDefinition, T> runner,
  }) {
    final resolver = StandardCommandResolverImpl<T>(runner);
    return resolver.resolveConfigurations(args, env, provider);
  }
}

class StandardCommandResolverImpl<T> {
  final CommandRunner<OptionDefinition, T> runner;

  StandardCommandResolverImpl(
    this.runner,
  );

  CommandContext<OptionDefinition, T> resolveConfigurations(
    final Iterable<String> args,
    final Map<String, String>? env,
    final ContextProvider? provider,
  ) {
    final argParseResult = scanAndParseCommands(
      args,
      rootCommand: runner,
      scanMode: ScanMode(
        doubleDashHandling: runner.ignoreUnexpectedPositionalArgs
            ? DoubleDashHandling.passThroughRest
            : DoubleDashHandling.noSpecialHandling,
      ),
    );

    final contexts = resolveNext(argParseResult, env, provider, null);

    if (helpOptionSpecified(contexts)) {
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
    final ContextProvider? provider,
    final CommandContext<OptionDefinition, T>? prevContext,
  ) {
    final command = argParseResult.command;
    if (command == null) throw StateError('ArgParseResult.command is null');
    if (command is! AbstractCommand<OptionDefinition, T>) {
      throw StateError(
        'ArgParseResult.command is not an AbstractCommand: ${command.runtimeType}',
      );
    }

    final context = resolveCmd(
      command,
      argParseResult,
      env,
      provider,
      prevContext,
    );

    if (argParseResult.child case final ArgParseResult child) {
      final nextContext = resolveNext(child, env, provider, context);
      context.next = nextContext;
    } else {
      context.next = null;
    }

    return context;
  }

  CommandContext<P, T> resolveCmd<P extends OptionDefinition>(
    final AbstractCommand<P, T> command,
    final ArgParseResult<P> parseResult,
    final Map<String, String>? env,
    final ContextProvider? provider,
    final CommandContext<OptionDefinition, T>? prevContext,
  ) {
    final Configuration<P> config = command.resolveCommandConfiguration(
      parsedArgs: NewParsedArgs(parseResult),
      env: env,
      configBroker: runner.configBroker,
      ignoreUnexpectedPositionalArgs: runner.ignoreUnexpectedPositionalArgs,
    );

    return command.buildRunContext(
      config,
      prevContext,
      provider,
    );
  }

  /// Throws a [CommandUsageException] if any command on the command line
  /// has configuration errors, including command line parse errors.
  void throwIfConfigurationErrors(
    final CommandContext<OptionDefinition, T> contexts,
  ) {
    final commandErrors = <(CommandDefinition, Iterable<String>)>[];
    CommandContext? context = contexts;
    while (context != null) {
      commandErrors.add((context.command, context.config.errors));
      context = context.next;
    }
    _throwIfErrors(commandErrors);
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
