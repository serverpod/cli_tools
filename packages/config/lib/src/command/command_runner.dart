import 'dart:async' show FutureOr;
import 'dart:io' show Platform, stderr;

import '../config/arg_parser/command_definition.dart';
import '../config/config.dart'
    show
        OptionDefinition,
        Configuration,
        ConfigurationBroker,
        FlagOption,
        UsageException,
        ConfigOptionBase;
import 'abstract_command.dart';
import 'command.dart';
import 'command_resolver.dart';
import 'command_run_context.dart';
import 'context_provider.dart';
import 'usage_output.dart';

/// T is the return type of the run methods of this runner and the commands.
/// [CommandRunner.runner] returns the result of the nested middleware chain.
/// When each middleware returns the result of its next handler, that is the
/// result of the last command on the command line.
/// This means that T must match across the runner and all its commands.
/// Using int as T can be sensible in order to return the exit code that the
/// command executable should return.
class CommandRunner<O extends OptionDefinition, T>
    extends AbstractCommand<O, T> {
  /// The name of the executable being run.
  ///
  /// Used for error reporting and [usage].
  final String executableName;

  /// The global option definitions (the root command's persistent options).
  List<O> get globalOptions => persistentOptions;

  /// The name of the executable being run.
  @override
  String get name => executableName;

  @override
  final CommandUsageDefinition usage;

  /// There are no aliases for the root command.
  @override
  final CommandAliasesDefinition aliases = const CommandAliasesDefinition();

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

  /// Resolves the configurations for each command on the command line.
  final CommandResolver<T> resolver = StandardCommandResolver<T>();

  /// Creates a new command runner with the given executable name and description.
  ///
  /// The [globalOptions] parameter is the list of global options.
  /// Global options are "persistent" which means they are valid anywhere on the
  /// command line.
  ///
  /// NOTE: If [globalOptions] is provided, the runner will not add the builtin
  /// `--help` / `-h` global option automatically.
  /// This option is typically desired, so if [globalOptions] are provided,
  /// also include the help option in its list, for example:
  /// ```dart
  /// <OptionDefinition>[...myGlobalOptions, CommandRunnerBuiltinOptions.help]
  /// ```
  /// It is also possible to specify a custom help option, in which case the
  /// CommandRunner's help functionality is skipped, allowing a fully custom
  /// `--help` behavior.
  ///
  /// The [subcommands] parameter is a list of subcommands that will be added to
  /// the runner. Can also be added later using [addSubcommand].
  ///
  /// The [middlewares] parameter is a list of middlewares that will be added to the runner.
  ///
  /// The [configBroker] parameter is a configuration broker that will be used to resolve the configurations.
  ///
  /// The [ignoreUnexpectedPositionalArgs] parameter is a boolean that determines whether unexpected positional arguments should be ignored.
  ///
  /// The [rootFooter] parameter is a string that will be added to the runner's usage footer.
  CommandRunner(
    this.executableName,
    final String description, {
    final List<O>? globalOptions,
    super.subcommands,
    super.middlewares,
    super.canRunAsLeafCommand = false,
    this.ignoreUnexpectedPositionalArgs = false,
    this.configBroker,
    this.usageOutput = const UsageOutputHandler(),
    final String? rootFooter,
  }) : usage = CommandUsageDefinition(
         description: description,
         usageFooter: rootFooter,
       ),
       super(persistentOptions: _globalOptions(globalOptions));

  static List<O> _globalOptions<O extends OptionDefinition>(
    final List<O>? globalOptions,
  ) {
    if (globalOptions != null) {
      return globalOptions;
    } else if (O == OptionDefinition || O == BuiltinGlobalOption) {
      return <O>[
        BuiltinGlobalOption.help as O,
      ];
    } else {
      throw ArgumentError(
        'globalOptions not provided and O is not assignable from BuiltinGlobalOption: $O',
      );
    }
  }

  /// Parses [args] and [env] (and [configBroker], when set)
  /// and invokes [Command.runCommand] on the commands on the command line.
  ///
  /// Returns a [FutureOr] in case the command is asynchronous.
  ///
  /// This resolves the global configuration and the individual command
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
  /// Throws [ConfigDefinitionError] if any command or option *definition* is
  /// invalid, before running any middleware or commands.
  ///
  /// Throws [UsageException] if any configuration input including arguments,
  /// environment variables, and configuration files is invalid,
  /// unless [CommandUsageSettings.noUsageException] is true.
  FutureOr<T?> runner(
    final Iterable<String> args, {
    final Map<String, String>? env,
    final ContextProvider? provider,
  }) {
    final envVars = env ?? Platform.environment;

    try {
      final cmdRunContexts = resolveConfigurations(args, envVars, provider);
      if (cmdRunContexts == null) return null;

      return _runCommandLine(cmdRunContexts);
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
  RunCommandContext<OptionDefinition, T>? resolveConfigurations(
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
    final RunCommandContext<OptionDefinition, T> runContexts,
  ) {
    final leafContext = runContexts.leaf();

    if (helpOptionSpecified(runContexts)) {
      usageOutput.printUsage(leafContext.command);
      return Future.value(null);
    }

    if (leafContext.command.runStandalone) {
      return _runStandaloneCommand(leafContext);
    }

    return _runNested(runContexts);
  }

  /// Runs the commands on the command line as one nested middleware chain.
  ///
  /// The first command's middleware is the outermost span. Each following
  /// command's middleware runs inside the previous command's middleware.
  /// Only the last command's [run] is invoked.
  FutureOr<T?> _runNested(
    final RunCommandContext<OptionDefinition, T> context,
  ) {
    final next = context.next == null
        ? null
        : (final RunCommandContext<OptionDefinition, T> forwarded) {
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
  /// Used for a command that runs on its own, such as a standalone command.
  FutureOr<T?> _runStandaloneCommand(
    final RunCommandContext<OptionDefinition, T> cmdRunContext,
  ) async {
    return await cmdRunContext.command.runCommand(cmdRunContext);
  }

  /// Runs this command runner when it is the last command on the command line.
  ///
  /// By default it does nothing, but can be overridden by subclasses.
  /// It can be used to implement what to do when no subcommands are specified.
  /// See also [CommandDefinition.canRunAsLeafCommand], which needs to be true
  /// to allow this root command to run without any subcommands.
  @override
  FutureOr<T?> run(final RunCommandContext<O, T> runContext) {
    return null;
  }
}

bool helpOptionSpecified(final RunCommandContext rootContext) {
  // The builtin help option can have been specified via its object
  // or via BuiltinGlobalOption enum, handle both cases.
  // If the user has specified a different help option, return false,
  // allowing a fully custom help behavior.
  final helpOption = rootContext.config.findOption(
    argName: 'help',
  );
  if (helpOption != null &&
      helpOption.option == CommandRunnerBuiltinOptions.help) {
    return rootContext.config.value(
      helpOption as OptionDefinition<bool>,
    );
  }
  return false;
}

abstract class CommandRunnerBuiltinOptions {
  static const help = FlagOption(
    argName: 'help',
    argAbbrev: 'h',
    defaultsTo: false,
    negatable: false,
    helpText: 'Show the usage help for a command.',
  );
}

enum BuiltinGlobalOption<V extends Object> implements OptionDefinition<V> {
  help(CommandRunnerBuiltinOptions.help);

  const BuiltinGlobalOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}
