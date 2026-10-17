import 'dart:async' show FutureOr;

import '../config/config.dart'
    show
        OptionDefinition,
        CommandDefinition,
        ParsedArgs,
        Configuration,
        ConfigurationBroker;
import '../middleware/middleware.dart';
import 'command.dart' show Command;
import 'command_run_context.dart';
import 'context_provider.dart';
import 'help_command.dart';

/// Common base class for all commands, [CommandRunner] and [Command].
abstract class AbstractCommand<O extends OptionDefinition, T>
    implements CommandDefinition<O> {
  @override
  final List<O> persistentOptions;

  @override
  final List<O> options;

  final List<Command<OptionDefinition, T>> _subcommands;

  final MiddlewareChain<FutureOr<T?>, RunCommandContext<O, T>> _middlewareChain;

  AbstractCommand({
    final List<O>? persistentOptions,
    final List<O>? options,
    final List<Command<OptionDefinition, T>>? subcommands,
    final List<Middleware<FutureOr<T?>, RunCommandContext<O, T>>>? middlewares,
    this.canRunAsLeafCommand = false,
  }) : persistentOptions = List.from(persistentOptions ?? []),
       options = List.from(options ?? []),
       _subcommands = List.from(subcommands ?? []),
       _middlewareChain = MiddlewareChain(middlewares);

  /// Informs the command runner to bypass all parent commands' middlewares
  /// and run methods and run this command's runCommand method directly,
  /// if this command is the last command on the command line.
  /// Typically used for commands like help and version.
  ///
  /// Note, this command's middlewares will still be invoked if present.
  bool get runStandalone => false;

  @override
  final bool canRunAsLeafCommand;

  void addMiddleware(
    final Middleware<FutureOr<T?>, RunCommandContext<O, T>> middleware,
  ) {
    _middlewareChain.addMiddleware(middleware);
  }

  /// Adds an option to this command.
  /// [persistent] indicates whether the option should be persistent across this
  /// command's subcommands.
  void addOption(final O option, {final bool? persistent}) {
    if (persistent == true) {
      persistentOptions.add(option);
    } else {
      options.add(option);
    }
  }

  /// Adds a subcommand to this command.
  void addSubcommand(final Command<OptionDefinition, T> subcommand) {
    _subcommands.add(subcommand);
  }

  /// Returns the subcommands for this command.
  /// Injects the help subcommand if there is at least one subcommand
  /// and there is not already a help command present.
  @override
  List<Command<OptionDefinition, T>> get subcommands {
    if (_subcommands.isEmpty) return [];
    final hasHelpCommand = _subcommands.any(
      (final command) => command.name == 'help',
    );
    return [
      ..._subcommands,
      if (!hasHelpCommand) HelpCommand(helpCommands: () => _subcommands),
    ];
  }

  /// Invoked by the command runner to resolve the configuration for this command.
  Configuration<O> resolveCommandConfiguration({
    final ParsedArgs? parsedArgs,
    final Map<String, String>? env,
    final ConfigurationBroker? configBroker,
    final bool ignoreUnexpectedPositionalArgs = false,
  }) {
    return Configuration.resolveNoExcept(
      options: [...persistentOptions, ...options],
      parsedArgs: parsedArgs,
      env: env,
      configBroker: configBroker,
      ignoreUnexpectedPositionalArgs: ignoreUnexpectedPositionalArgs,
    );
  }

  /// Invoked by the command runner to build the run context for this command.
  RunCommandContext<O, T> buildRunContext(
    final Configuration<O> configuration,
    final RunCommandContext<OptionDefinition, T>? prev,
    final ContextProvider? provider,
  ) {
    return RunCommandContext<O, T>(
      command: this,
      config: configuration,
      prev: prev,
      provider: provider,
    );
  }

  /// Invoked by the command runner to run this command,
  /// including its middlewares (hooks).
  ///
  /// When [runNextCommand] is omitted, this command is run,
  /// wrapped by the middlewares of this command.
  /// When [runNextCommand] is provided, it is run instead of [run],
  /// wrapped by the middlewares of this command.
  ///
  /// Typically not overridden by subclasses.
  FutureOr<T?> runCommand(
    final RunCommandContext<O, T> runContext, {
    final Handler<FutureOr<T?>, RunCommandContext<O, T>>? runNextCommand,
  }) {
    final terminalHandler = runNextCommand ?? run;
    final handler = _handlerChain(terminalHandler);
    return handler(runContext);
  }

  /// Builds a handler chain with this command's middlewares,
  /// concluded with the given terminal handler.
  Handler<FutureOr<T?>, RunCommandContext<O, T>> _handlerChain(
    final Handler<FutureOr<T?>, RunCommandContext<O, T>> terminalHandler,
  ) => _middlewareChain.handlerChain(terminalHandler);

  /// Runs this command. Implemented by subclasses.
  ///
  /// Invoked only when this command is the last command on the command line.
  FutureOr<T?> run(final RunCommandContext<O, T> runContext);
}
