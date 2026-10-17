import '../config/arg_parser/arg_parser.dart';
import '../config/arg_parser/arg_scanner.dart'
    show ScanMode, DoubleDashHandling;
import '../config/config.dart'
    show
        OptionDefinition,
        Configuration,
        UsageException,
        CommandUsageException,
        NewParsedArgs;
import '../config/output_formatting.dart' show formatConfigError;
import 'abstract_command.dart';
import 'command_run_context.dart';
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
  RunCommandContext<OptionDefinition, T> resolveConfigurations(
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
  RunCommandContext<OptionDefinition, T> resolveConfigurations(
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

  RunCommandContext<OptionDefinition, T> resolveConfigurations(
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

    final cmdRunContexts = resolveNext(argParseResult, env, provider, null);

    if (helpOptionSpecified(cmdRunContexts)) {
      return cmdRunContexts;
    }

    throwIfConfigurationErrors(cmdRunContexts);

    return cmdRunContexts;
  }

  RunCommandContext<OptionDefinition, T> resolveNext(
    final ArgParseResult<OptionDefinition> argParseResult,
    final Map<String, String>? env,
    final ContextProvider? provider,
    final RunCommandContext<OptionDefinition, T>? prevContext,
  ) {
    final command = argParseResult.command;
    if (command == null) throw StateError('ArgParseResult.command is null');
    if (command is! AbstractCommand<OptionDefinition, T>) {
      throw StateError(
        'ArgParseResult.command is not an AbstractCommand: ${command.runtimeType}',
      );
    }

    final cmdRunContext = resolveCmd(
      command,
      argParseResult,
      env,
      provider,
      prevContext,
    );

    if (argParseResult.child case final ArgParseResult child) {
      final nextContext = resolveNext(child, env, provider, cmdRunContext);
      cmdRunContext.next = nextContext;
    } else {
      cmdRunContext.next = null;
    }

    return cmdRunContext;
  }

  RunCommandContext<P, T> resolveCmd<P extends OptionDefinition>(
    final AbstractCommand<P, T> command,
    final ArgParseResult<P> parseResult,
    final Map<String, String>? env,
    final ContextProvider? provider,
    final RunCommandContext<OptionDefinition, T>? prevContext,
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

  void throwIfConfigurationErrors(
    final RunCommandContext<OptionDefinition, T> runContexts,
  ) {
    final messages = <String>[];
    AbstractCommand? firstCommandWithErrors;

    RunCommandContext? context = runContexts;
    while (context != null) {
      final name = context.command.name;
      final errors = context.config.errors.map(
        (final error) => '$name: ${formatConfigError(error)}',
      );
      if (errors.isNotEmpty) {
        messages.addAll(errors);
        firstCommandWithErrors ??= context.command;
      }

      context = context.next;
    }

    if (firstCommandWithErrors != null) {
      throw CommandUsageException(messages.join('\n'), firstCommandWithErrors);
    }
  }
}
