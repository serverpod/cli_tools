import 'dart:async' show FutureOr;

import '../../middleware.dart' show MiddlewareChain, Middleware;
import '../config/config.dart'
    show
        OptionDefinition,
        CommandDefinition,
        ParsedArgs,
        Configuration,
        ConfigurationBroker;
import 'command.dart' show Command;
import 'command_context.dart';
import 'command_middleware.dart';
import 'context_provider.dart';
import 'help_command.dart';
import 'usage_generator.dart' show UsageGenerator;

/// Common base class for all commands, [CommandRunner] and [Command].
abstract class AbstractCommand<O extends OptionDefinition, T>
    implements CommandDefinition<O> {
  final UsageGenerator usageGenerator;

  /// If non-null, specifies the line length for usage output wrapping.
  int? usageLineLength;

  @override
  final List<O> persistentOptions;

  @override
  final List<O> options;

  @override
  final bool canRunAsLeafCommand;

  AbstractCommand<OptionDefinition, T>? _parent;

  final List<Command<OptionDefinition, T>> _subcommands;

  /// Built-in subcommands, see [subcommands].
  final List<Command<OptionDefinition, T>> _builtinSubcommands;

  /// The built-in help command, created lazily since every command,
  /// including the help command itself, has one.
  late final HelpCommand<T> _helpCommand = HelpCommand<T>().._parent = this;

  final MiddlewareChain<FutureOr<T?>, CommandContext<O, T>> _middlewareChain;

  /// [builtinSubcommands] are added after the defined [subcommands] when
  /// this command has subcommands, unless a subcommand with the same name
  /// is defined. The `help` command is always built in, as the last one.
  AbstractCommand({
    required this.usageGenerator,
    this.usageLineLength,
    final List<O>? persistentOptions,
    final List<O>? options,
    final List<Command<OptionDefinition, T>>? subcommands,
    final List<Command<OptionDefinition, T>>? builtinSubcommands,
    final List<CommandMiddleware<O, T>>? middlewares,
    this.canRunAsLeafCommand = false,
  }) : persistentOptions = List.from(persistentOptions ?? []),
       options = List.from(options ?? []),
       _subcommands = List.from(subcommands ?? []),
       _builtinSubcommands = List.from(builtinSubcommands ?? []),
       _middlewareChain = MiddlewareChain(middlewares) {
    for (final subcommand in [..._subcommands, ..._builtinSubcommands]) {
      subcommand._parent = this;
    }
  }

  @override
  String get usage => usageGenerator.generate(this);

  /// Informs the command runner to bypass all parent commands' middlewares
  /// and run this command's runCommand method directly,
  /// if this command is the last command on the command line.
  /// Typically used for commands like help and version.
  ///
  /// Note, this command's middlewares will still be invoked if present.
  bool get runStandalone => false;

  /// Whether this command accepts a partial command line, i.e. runs as the
  /// last command on the command line even if this or the preceding commands
  /// have configuration errors, such as missing mandatory options, mutually
  /// exclusive groups without a mandatory choice, or invalid option values.
  /// These errors remain available in `CommandContext.config.errors`.
  /// Command line parse errors, such as unknown options or subcommands,
  /// are still raised.
  ///
  /// True for the built-in help command, which shows the usage of the
  /// preceding command regardless of whether its arguments are complete,
  /// like the `--help` option does. Custom `CommandResolver`s should
  /// honor this.
  bool get acceptsPartialCommandLine => false;

  bool get hasParent => _parent != null;

  AbstractCommand<OptionDefinition, T> get parent {
    if (_parent == null) throw StateError('Parent command of $name not set');
    return _parent!;
  }

  void addMiddleware(
    final Middleware<FutureOr<T?>, CommandContext<O, T>> middleware,
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
    subcommand._parent = this;
  }

  /// Returns the subcommands for this command.
  /// Injects the built-in subcommands (including `help`) if there is
  /// at least one subcommand and there is not already a subcommand with
  /// the same name present.
  @override
  List<Command<OptionDefinition, T>> get subcommands {
    if (_subcommands.isEmpty) return [];
    return [
      ..._subcommands,
      for (final builtin in [..._builtinSubcommands, _helpCommand])
        if (!_subcommands.any((final command) => command.name == builtin.name))
          builtin,
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
  CommandContext<O, T> buildRunContext(
    final Configuration<O> configuration,
    final CommandContext<OptionDefinition, T>? prev,
    final ContextProvider? provider,
  ) {
    return CommandContext<O, T>(
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
    final CommandContext<O, T> context, {
    final CommandHandler<O, T>? runNextCommand,
  }) {
    final terminalHandler = runNextCommand ?? run;
    final handler = _handlerChain(terminalHandler);
    return handler(context);
  }

  /// Builds a handler chain with this command's middlewares,
  /// concluded with the given terminal handler.
  CommandHandler<O, T> _handlerChain(
    final CommandHandler<O, T> terminalHandler,
  ) => _middlewareChain.handlerChain(terminalHandler);

  /// Runs this command. Implemented by subclasses.
  ///
  /// Invoked only when this command is the last command on the command line.
  FutureOr<T?> run(final CommandContext<O, T> context);
}
