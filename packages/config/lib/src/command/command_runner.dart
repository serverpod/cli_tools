import 'dart:async' show FutureOr;
import 'dart:io' show Platform, stderr;

import '../config/arg_parser/arg_parser.dart'
    show CommandAliasesDefinition, CommandDefinition, CommandUsageDefinition;
import '../config/config.dart'
    show
        OptionDefinition,
        Configuration,
        UsageException,
        ParsedArgs,
        ConfigOptionBase,
        FlagOption,
        MultiOption,
        ArgParseResult,
        NewParsedArgs;
import 'abstract_command.dart';
import 'builtin_global_option.dart';
import 'command_context.dart';
import 'command_resolver.dart';
import 'context_provider.dart';
import 'usage_generator.dart' show StandardRunnerUsageGenerator, UsageGenerator;
import 'usage_output.dart';

/// A command runner for a command line application.
///
/// Runs a command line by parsing the command line arguments, environment variables,
/// and configuration files, and running the commands on the command line.
///
/// Returns the result of the nested middleware chain for the commands on
/// the command line. Each ancestor's middleware wraps the commands that
/// follow it. Only the last command's [run] is invoked.
///
/// T is the return type of the run methods of this runner and the commands.
/// [CommandRunner.run] returns the result of the nested middleware chain.
/// When each middleware returns the result of its next handler, that is the
/// result of the last command on the command line.
/// This means that T must match across the runner and all its commands.
/// Using int as T can be sensible in order to return the exit code that the
/// command executable should return.
///
/// ## Design
///
/// Uses the concept of middlewares to customize the execution logic
/// of the command tree. The legacy CommandRunner relied on method overrides
/// to customize the execution logic. This middleware approach allows for
/// cleaner composition.
///
/// Separates static configuration from dynamic execution. The command tree,
/// options, middlewares, settings for usage output and error handling are
/// configured statically. Execution performs configuration resolution and
/// command execution and these do not mutate the CommandRunner, Command, or
/// Option instances. This provides separation of concerns and makes the command
/// code reentrant.
///
/// ## Phases and Error Handling
///
/// There are three phases to the execution of a command runner that are run
/// in sequence and have distinct error handling:
/// 1. Validation: Checking the consistency of the commands and options
/// 2. Resolution: Resolving the configurations for the command line, env vars, and config files
/// 3. Execution: Running the command line and any middlewares
///
/// Configuration validation runs first and validates the consistency of all the
/// defined commands and options. Validation errors are considered programming
/// errors and if any errors are found a [ConfigDefinitionError] is thrown.
///
/// Configuration resolution runs next and resolves the current configurations
/// for the command line, env vars, and config files. Resolution errors are user
/// errors and if any errors are found, usage guidance is printed and a
/// [UsageException] is thrown (under the default settings).
///
/// Command execution is last and runs the current command line and any
/// middlewares defined in it. If any exceptions are thrown they will propagate
/// to the original caller unless intercepted by a middleware.
class CommandRunner<O extends OptionDefinition, T>
    extends AbstractCommand<O, T> {
  /// The name of the executable being run.
  ///
  /// Used for error reporting and [usageDefinition].
  final String executableName;

  /// The global option definitions (the root command's persistent options).
  List<O> get globalOptions => persistentOptions;

  /// The built-in global options, e.g. `--help`.
  List<BuiltinGlobalOption> get builtinPersistentOptions => [
    BuiltinGlobalOption.help,
  ];

  @override
  List<OptionDefinition> allOptions({final bool onlyPersistent = false}) => [
    ...builtinPersistentOptions,
    ...persistentOptions,
    if (!onlyPersistent) ...options,
  ];

  /// The name of the executable being run.
  @override
  String get name => executableName;

  @override
  final CommandUsageDefinition usageDefinition;

  /// There are no aliases for the root command.
  @override
  final CommandAliasesDefinition aliasesDefinition =
      const CommandAliasesDefinition();

  /// Whether a positional argument that matches no positional option is allowed.
  /// If true, such arguments are included in [Configuration.remainingPosArgs]
  /// of the last command's configuration.
  /// This also enables the `--` double dash argument, which stops parsing of
  /// the command line and instead puts the following arguments in
  /// [Configuration.remainingPosArgs] of the last parsed command.
  ///
  /// When false, the default, those arguments are included in the
  /// [UsageException] thrown before any command runs.
  final bool ignoreUnexpectedPositionalArgs;

  /// The maximum edit distance allowed when suggesting possible intended
  /// commands.
  ///
  /// Set to `0` in order to disable suggestions, defaults to `2`.
  final int suggestionDistanceLimit;

  /// The settings and behavior for the usage output -
  /// controls the help output and the usage exception output.
  final UsageOutputHandler usageOutput;

  /// Resolves the configurations for each command on the command line.
  final CommandResolver<O, T> resolver = StandardCommandResolver<O, T>();

  /// Creates a new command runner with the given executable name and description.
  ///
  /// [globalOptions] is the list of global options.
  /// Global options are "persistent" which means they are valid anywhere on the
  /// command line.
  ///
  /// The built-in global option `--help` / `-h` is available in addition,
  /// see [builtinPersistentOptions].
  ///
  /// [subcommands] is a list of subcommands that will be added to
  /// the runner. Can also be added later using [addSubcommand].
  ///
  /// [middlewares] is a list of middlewares that will be added to the runner.
  ///
  /// [ignoreUnexpectedPositionalArgs] is a boolean that determines whether unexpected positional arguments should be ignored.
  ///
  /// [rootFooter] is a string that will be added to the runner's usage footer.
  CommandRunner(
    this.executableName,
    final String description, {
    final List<O>? globalOptions,
    final String? rootFooter,
    super.subcommands,
    super.middlewares,
    super.canRunAsLeafCommand,
    super.usageLineLength,
    final UsageGenerator? usageGenerator,
    final bool? ignoreUnexpectedPositionalArgs,
    final int? suggestionDistanceLimit,
    final UsageOutputHandler? usageOutput,
  }) : usageDefinition = CommandUsageDefinition(
         description: description,
         usageFooter: rootFooter,
       ),
       usageOutput = usageOutput ?? UsageOutputHandler(),
       ignoreUnexpectedPositionalArgs = ignoreUnexpectedPositionalArgs ?? false,
       suggestionDistanceLimit = suggestionDistanceLimit ?? 2,
       super(
         usageGenerator: usageGenerator ?? const StandardRunnerUsageGenerator(),
         persistentOptions: globalOptions,
       );

  /// Runs a command line by parsing [args] and [env] (and [configBroker], when
  /// available) and running the last command on the command line.
  ///
  /// Returns a [Future] with the result. Synchronous work runs immediately,
  /// and a synchronous command result is still delivered on the future.
  ///
  /// Resolves the global configuration and the individual command
  /// configurations before invoking the commands or their middlewares.
  /// Throws a [UsageException] on [args] parse errors and configuration
  /// resolution errors. All discovered parse and resolution errors are included
  /// in the message of that exception.
  ///
  /// The caller may provide a [ContextProvider], otherwise a default, empty
  /// one is created and used.
  ///
  /// Returns the result of the nested middleware chain for the commands on
  /// the command line. Each ancestor's middleware wraps the commands that
  /// follow it. Only the last command's [run] is invoked. When every
  /// middleware returns the result of its next handler, the result is that
  /// of the last command.
  ///
  /// When `--help`, `-h`, or a `help` command is present on a command
  /// line, prints usage for the last command and returns `null` without
  /// running any command.
  ///
  /// To make a subcommand which is named like an option, simply define it, for example:
  /// ```dart
  ///  CommandImpl.leafWithRunFunction(
  ///    name: 'version',
  ///    aliases: ['--version', '-v'],
  ///    description: 'Display the version',
  ///    run: (CommandContext context) {
  ///      print('version 1.0.0');
  ///    },
  ///  );
  /// ```
  ///
  /// Throws [ConfigDefinitionError] if any command or option *definition* is
  /// invalid, before running any middleware or commands.
  ///
  /// Throws [UsageException] if any configuration input including arguments,
  /// environment variables, and configuration files is invalid,
  /// unless [CommandUsageSettings.noUsageException] is true.
  Future<T?> run(
    final Iterable<String> args, {
    final Map<String, String>? env,
    final ContextProvider? provider,
  }) async {
    try {
      return await Future.sync(
        () => _run(args, env: env, customProvider: provider),
      );
    } on TypeError catch (error, stackTrace) {
      stderr.writeln(
        ">>> If this happens, O and T may need to be bound explicitly, due to limitations in Dart's generic type inference.\n"
        '    E.g. `CommandRunner<OptionDefinition, int>(...)`\n'
        '${error.runtimeType}: $error\n'
        '$stackTrace',
      );
      rethrow;
    }
  }

  FutureOr<T?> _run(
    final Iterable<String> args, {
    final Map<String, String>? env,
    final ContextProvider? customProvider,
  }) {
    final envVars = env ?? Platform.environment;
    final argList = args.toList();

    final provider = customProvider ?? ContextProvider();
    final contexts = resolveConfigurations(argList, envVars, provider);
    if (contexts == null) return null;

    contexts.provider.store(OriginalCommandLine(argList));

    return runCommandLine(contexts);
  }

  /// Resolves the configurations for all commands on the command line
  /// and returns the list of contexts for the commands.
  ///
  /// On configuration input errors (including command line arguments,
  /// environment variables, and configuration files), a usage error message
  /// is printed and a [UsageException] is thrown.
  /// This behavior can be changed by passing a custom [UsageOutputHandler]
  /// on construction, for example by suppressing UsageException from being
  /// thrown in which case null is returned instead.
  ///
  /// If null is returned, the runner returns null without running any command.
  ///
  /// This method can be overridden by subclasses.
  CommandContext<O, T>? resolveConfigurations(
    final Iterable<String> args,
    final Map<String, String>? env,
    final ContextProvider provider,
  ) {
    try {
      return resolver.resolveConfigurations(args, env, provider, runner: this);
    } on UsageException catch (e, s) {
      final exception = usageOutput.onUsageException(e, fromCommand: this);
      if (exception == null) return null;
      Error.throwWithStackTrace(exception, s);
    }
  }

  @override
  CommandContext<O, T> resolveCmd(
    final ArgParseResult parseResult,
    final Map<String, String>? env,
    final ContextProvider provider,
    final CommandContext<OptionDefinition, T>? prevContext,
  ) {
    final parsedArgs = NewParsedArgs(parseResult);

    final Configuration<O> config = Configuration.resolveNoExcept(
      options: [...persistentOptions, ...options],
      parsedArgs: parsedArgs,
      env: env,
      configBroker: configBroker(prevContext),
      ignoreUnexpectedPositionalArgs: runner.ignoreUnexpectedPositionalArgs,
    );

    // Note, parse errors and positional arguments of [parsedArgs] belong to the
    // regular configuration and are not reported again here.
    final builtinConfig = Configuration.resolveNoExcept(
      options: builtinPersistentOptions,
      parsedArgs: _FilteredParsedArgs(parsedArgs),
      env: env,
    );

    return CommandContext<O, T>(
      command: this,
      config: config,
      builtinConfig: builtinConfig,
      prev: prevContext,
      provider: provider,
    );
  }

  /// Runs the command line, i.e. the middlewares of the commands on the command
  /// line and run the tail command.
  /// Some commands have special handling, such as help, and
  /// commands flagged with runStandalone=true which skip middlewares of their
  /// parents.
  ///
  /// This method can be overridden by subclasses to wrap this behavior,
  /// although it is recommended to use middlewares instead.
  FutureOr<T?> runCommandLine(final CommandContext<O, T> contexts) {
    final leafContext = contexts.leaf();

    if (_helpOptionSpecified(contexts)) {
      usageOutput.printUsage(leafContext.command);
      return Future.value(null);
    }

    if (leafContext.command.runStandalone) {
      return _runStandaloneCommand(leafContext);
    }

    return _runNested(contexts);
  }

  /// Runs the commands on the command line as one nested middleware chain.
  ///
  /// The first command's middleware is the outermost span. Each following
  /// command's middleware runs inside the previous command's middleware.
  /// Only the last command's [run] is invoked.
  FutureOr<T?> _runNested(
    final CommandContext<OptionDefinition, T> context,
  ) {
    final next = context.next == null
        ? null
        : (final CommandContext<OptionDefinition, T> forwarded) {
            // (forwarded context may have been replaced by a middleware)
            final next = forwarded.next;
            if (next == null) {
              throw StateError(
                '${forwarded.command.name} has no following command.',
              );
            }
            return _runNested(next);
          };

    return context.command.runCommand(context, runNextCommand: next);
  }

  /// Runs one command with its own middleware and no following commands.
  /// Used for a command that runs on its own, such as a help command.
  FutureOr<T?> _runStandaloneCommand(
    final CommandContext<OptionDefinition, T> context,
  ) async {
    return await context.command.runCommand(context);
  }

  /// Runs this command runner when it is the last command on the command line.
  ///
  /// By default it prints the usage for the command, but this can be overridden
  /// by subclasses.
  /// See also [CommandDefinition.canRunAsLeafCommand], which needs to be true
  /// to allow this root command to run without any subcommands.
  @override
  FutureOr<T?> runAsLeaf(final CommandContext<O, T> context) {
    usageOutput.printUsage(context.command);
    return null;
  }
}

/// The value of the built-in global [option] on the command line,
/// or null if the option is not available or not given.
V? builtinOptionValue<V extends Object>(
  final CommandContext rootContext,
  final BuiltinGlobalOption<V> option,
) {
  final config = rootContext.builtinConfig;
  if (!config.options.contains(option)) return null;
  return config.optionalValue(option);
}

/// Whether the built-in `--help` option is given on the command line.
bool _helpOptionSpecified(final CommandContext rootContext) {
  return builtinOptionValue(rootContext, BuiltinGlobalOption.help) ?? false;
}

/// Whether a built-in option that acts on the command line as given
/// (`--help`) is specified.
bool builtinActionOptionSpecified(final CommandContext rootContext) {
  return _helpOptionSpecified(rootContext);
}

class OriginalCommandLine {
  final List<String> args;

  OriginalCommandLine(this.args);
}

/// The parsed option values of a command, without its parse errors and
/// positional arguments, which belong to the command's own configuration.
class _FilteredParsedArgs implements ParsedArgs {
  final ParsedArgs _args;

  _FilteredParsedArgs(this._args);

  @override
  bool wasParsed(final ConfigOptionBase option) => _args.wasParsed(option);

  @override
  bool flag(final FlagOption option) => _args.flag(option);

  @override
  String option(final ConfigOptionBase option) => _args.option(option);

  @override
  List<String> multiOption(final MultiOption option) =>
      _args.multiOption(option);

  @override
  List<String> get rest => const [];

  @override
  List<String> get parseErrors => const [];
}
