import 'dart:async' show FutureOr;
import 'dart:io' show Platform, stderr;

import '../config/arg_parser/arg_parser.dart'
    show CommandAliasesDefinition, CommandDefinition, CommandUsageDefinition;
import '../config/config.dart'
    show OptionDefinition, Configuration, ConfigurationBroker, UsageException;
import 'abstract_command.dart';
import 'builtin_global_option.dart';
import 'command_context.dart';
import 'command_resolver.dart';
import 'completion/completion.dart';
import 'context_provider.dart';
import 'usage_generator.dart' show StandardRunnerUsageGenerator, UsageGenerator;
import 'usage_output.dart';

/// T is the return type of the run methods of this runner and the commands.
/// [CommandRunner.run] returns the result of the nested middleware chain.
/// When each middleware returns the result of its next handler, that is the
/// result of the last command on the command line.
/// This means that T must match across the runner and all its commands.
/// Using int as T can be sensible in order to return the exit code that the
/// command executable should return.
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
  @override
  List<BuiltinGlobalOption> get builtinPersistentOptions => [
    BuiltinGlobalOption.help,
    if (completion.enabled && subcommands.isEmpty)
      BuiltinGlobalOption.completion,
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

  /// The configuration broker used while resolving the configurations, if any.
  final ConfigurationBroker? configBroker;

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

  /// The settings and behavior for the usage output -
  /// controls the help output and the usage exception output.
  final UsageOutputHandler usageOutput;

  /// The settings for the built-in shell completion support.
  ///
  /// Enabled by default, see [CompletionSettings].
  final CompletionSettings completion;

  /// Resolves the configurations for each command on the command line.
  final CommandResolver<T> resolver = StandardCommandResolver<T>();

  /// Creates a new command runner with the given executable name and description.
  ///
  /// [globalOptions] is the list of global options.
  /// Global options are "persistent" which means they are valid anywhere on the
  /// command line.
  ///
  /// The built-in global option `--help` / `-h` is available in addition,
  /// as is `--completion <shell>` for a runner without subcommands,
  /// see [builtinPersistentOptions].
  ///
  /// [subcommands] is a list of subcommands that will be added to
  /// the runner. Can also be added later using [addSubcommand].
  ///
  /// [middlewares] is a list of middlewares that will be added to the runner.
  ///
  /// [configBroker] is a configuration broker that will be used to resolve the configurations.
  ///
  /// [ignoreUnexpectedPositionalArgs] is a boolean that determines whether unexpected positional arguments should be ignored.
  ///
  /// [rootFooter] is a string that will be added to the runner's usage footer.
  ///
  /// [completion] configures the built-in shell completion support,
  /// which is enabled by default. See [CompletionSettings].
  CommandRunner(
    this.executableName,
    final String description, {
    final List<O>? globalOptions,
    final String? rootFooter,
    super.subcommands,
    super.middlewares,
    super.canRunAsLeafCommand = false,
    final UsageGenerator? usageGenerator,
    super.usageLineLength,
    this.ignoreUnexpectedPositionalArgs = false,
    this.configBroker,
    this.usageOutput = const UsageOutputHandler(),
    this.completion = const CompletionSettings(),
  }) : usageDefinition = CommandUsageDefinition(
         description: description,
         usageFooter: rootFooter,
       ),
       super(
         usageGenerator: usageGenerator ?? const StandardRunnerUsageGenerator(),
         persistentOptions: globalOptions,
         builtinSubcommands: [
           if (completion.enabled)
             CompletionCommand<T>(hidden: completion.hideCommand),
         ],
       );

  /// Runs a command line by parsing [args] and [env] (and [configBroker], when
  /// set) and running the last command on the command line.
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
  ///   CommandImpl.withRunFunction(
  ///     name: 'version',
  ///     aliases: ['--version', '-v'],
  ///     description: 'Display the version',
  ///     run: (CommandContext context) {
  ///       print('version 1.0.0');
  ///     },
  ///   ),
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
        () => _run(args, env: env, provider: provider),
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
    final ContextProvider? provider,
  }) {
    final envVars = env ?? Platform.environment;

    if (completion.enabled) {
      final argList = args.toList();
      if (argList.isNotEmpty && argList.first == _completeRequestCommand) {
        return _serveCompletionRequest(argList.sublist(1), envVars);
      }
    }

    final contexts = resolveConfigurations(args, envVars, provider);
    if (contexts == null) return null;

    return _runCommandLine(contexts);
  }

  /// Serves a completion request from a shell completion script:
  /// writes the completion alternatives for the partial command line
  /// [words] to the usage output.
  ///
  /// Completion requests are served before any configuration resolution:
  /// no middlewares run and no option values are resolved, so environment
  /// variables, configuration files and the configuration broker are not
  /// consulted for option values.
  ///
  /// The [env] map is only passed through to custom `ConfigOptionBase.complete`
  /// implementations, as `CompletionContext.environment`.
  ///
  /// Exits the process with 0 after writing the response unless
  /// [CompletionSettings.exitAfterResponse] is false.
  Future<T?> _serveCompletionRequest(
    final List<String> words,
    final Map<String, String> env,
  ) async {
    final engine = CompletionEngine(
      this,
      ignoreUnexpectedPositionalArgs: ignoreUnexpectedPositionalArgs,
      onError: (final error, final stackTrace) {
        usageOutput.sinks.err.writeln('Completion failed: $error\n$stackTrace');
      },
    );
    final response = await engine.complete(words, environment: env);
    await writeCompletionOutput(this, response.format());
    return null;
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
  CommandContext<OptionDefinition, T>? resolveConfigurations(
    final Iterable<String> args,
    final Map<String, String>? env,
    final ContextProvider? provider,
  ) {
    try {
      return resolver.resolveConfigurations(args, env, provider, runner: this);
    } on UsageException catch (e, s) {
      final exception = usageOutput.onUsageException(e, fromCommand: this);
      if (exception == null) return null;
      Error.throwWithStackTrace(exception, s);
    }
  }

  /// Runs the command line.
  FutureOr<T?> _runCommandLine(
    final CommandContext<OptionDefinition, T> contexts,
  ) {
    final leafContext = contexts.leaf();

    if (_helpOptionSpecified(contexts)) {
      usageOutput.printUsage(leafContext.command);
      return Future.value(null);
    }

    if (_completionShellSpecified(contexts) case final CompletionShell shell) {
      // Exits the process after writing the script unless
      // CompletionSettings.exitAfterResponse is false.
      return printCompletionScript(this, shell).then((final _) => null);
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
  /// By default it does nothing, but can be overridden by subclasses.
  /// It can be used to implement what to do when no subcommands are specified.
  /// See also [CommandDefinition.canRunAsLeafCommand], which needs to be true
  /// to allow this root command to run without any subcommands.
  @override
  FutureOr<T?> runAsLeaf(final CommandContext<O, T> context) {
    return null;
  }
}

/// The hidden built-in root command word that serves completion requests
/// from the shell completion scripts.
///
/// The request has the form:
/// ```
/// <executable> __complete <word>... <word-to-complete>
/// ```
/// where the words are the command line arguments typed so far and the last
/// word is the (possibly empty) partial word being completed.
///
/// The response on stdout is one line per completion candidate, in the form
/// `value` or `value<TAB>description`, followed by a final line `:<N>`
/// where N is the sum of the [CompletionDirective] flags.
///
/// This is the protocol of Cobra's `__complete` command, which is understood
/// by third-party completion engines such as Carapace.
const String _completeRequestCommand = '__complete';

/// The value of the built-in global [option] on the command line,
/// or null if the option is not available (e.g. completion is disabled)
/// or not given.
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

/// The shell given to the built-in `--completion <shell>` option
/// on the command line, or null if not given.
CompletionShell? _completionShellSpecified(final CommandContext rootContext) {
  return builtinOptionValue(rootContext, BuiltinGlobalOption.completion);
}

/// Whether a built-in option that acts on the command line as given
/// (`--help` or `--completion`) is specified. When it is, the command line
/// is not run and its remaining errors are not reported.
bool builtinActionOptionSpecified(final CommandContext rootContext) {
  return _helpOptionSpecified(rootContext) ||
      _completionShellSpecified(rootContext) != null;
}
