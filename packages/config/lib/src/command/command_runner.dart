import 'dart:async' show FutureOr;
import 'dart:io' show Platform;

import '../config/arg_parser/arg_parser.dart';
import '../config/arg_parser/arg_scanner.dart'
    show ScanMode, DoubleDashHandling;
import '../config/arg_parser/command_definition.dart';
import '../config/arg_parser_facade.dart';
import '../config/config.dart'
    show
        OptionDefinition,
        Configuration,
        ConfigurationBroker,
        FlagOption,
        UsageException,
        ConfigOptionBase,
        CommandUsageException;
import '../config/output_formatting.dart' show formatConfigError;
import 'abstract_command.dart';
import 'command.dart';
import 'command_run_context.dart';
import 'command_usage.dart';
import 'context_provider.dart';
import 'usage_output_settings.dart';

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
  ConfigurationBroker? configBroker;

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

  /// The settings for the usage output.
  final UsageOutputSettings usageOutputSettings;

  /// The printer for the usage output.
  final CommandUsagePrinter usagePrinter;

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
  /// The [footer] parameter is a string that will be added to the runner's usage footer.
  CommandRunner(
    this.executableName,
    final String description, {
    final List<O>? globalOptions,
    super.subcommands,
    super.middlewares,
    super.canRunAsLeafCommand = false,
    this.ignoreUnexpectedPositionalArgs = false,
    this.configBroker,
    this.usageOutputSettings = const UsageOutputSettings(),
    this.usagePrinter = const DefaultCommandUsagePrinter(),
    final String? footer, // TODO: revise
  }) : usage = CommandUsageDefinition(
         description: description,
         usageFooter: footer,
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
  /// resolution errors. All parse and resolution errors are included
  /// in that exception.
  ///
  /// Returns the result of the nested middleware chain for the commands on
  /// the command line. Each ancestor's middleware wraps the commands that
  /// follow it. Only the last command's [run] is invoked. When every
  /// middleware returns the result of its next handler, the result is that
  /// of the last command.
  /// When `--help`, `-h`, or a `help` command is present on a valid command
  /// line, prints usage for the last command and returns `null` without
  /// running any command.
  ///
  /// Throws [ConfigDefinitionError] if any command or option *definition* is invalid.
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

    final RunCommandContext<OptionDefinition, T>? cmdRunContexts;
    try {
      cmdRunContexts = _resolveConfigurations(args, envVars, provider);
    } on UsageException catch (e) {
      if (!usageOutputSettings.noUsageExceptionOutput) {
        printUsageException(e);
      }
      if (usageOutputSettings.noUsageException) {
        return null;
      }
      rethrow;
    }

    final leafContext = cmdRunContexts.leaf();

    if (_helpOptionSpecified(cmdRunContexts)) {
      printUsage(leafContext.command, usageOutputSettings.out);
      return Future.value(null);
    }

    if (leafContext.command.runStandalone) {
      return _runStandaloneCommand(leafContext);
    }

    return _runCommandLine(cmdRunContexts);
  }

  void printUsageException(final UsageException e) {
    usageOutputSettings.err.writeln(e.message);
    usageOutputSettings.err.writeln('');

    if (e is CommandUsageException) {
      printUsage(e.command, usageOutputSettings.err);
    } else {
      if (e.usage.isNotEmpty) {
        usageOutputSettings.err.writeln(e.usage);
        usageOutputSettings.err.writeln('---');
      }
      printUsage(this, usageOutputSettings.err);
    }
  }

  void printUsage([final CommandDefinition? command, final StringSink? out]) {
    usagePrinter.print(command ?? this, out ?? usageOutputSettings.out);
  }

  /// Resolves the configurations for each command on the command line.
  ///
  /// Throws [UsageException] on configuration input errors including
  /// command line arguments, environment variables, and configuration files.
  RunCommandContext<OptionDefinition, T> _resolveConfigurations(
    final Iterable<String> args,
    final Map<String, String>? env,
    final ContextProvider? provider,
  ) {
    final argParseResult = scanAndParseCommands(
      args,
      rootCommand: this,
      scanMode: ScanMode(
        doubleDashHandling: ignoreUnexpectedPositionalArgs
            ? DoubleDashHandling.passThroughRest
            : DoubleDashHandling.noSpecialHandling,
      ),
    );

    final cmdRunContexts = _resolveNext(argParseResult, env, null, provider);

    _throwIfConfigurationErrors(cmdRunContexts, argParseResult);

    return cmdRunContexts;
  }

  RunCommandContext<OptionDefinition, T> _resolveNext(
    final ArgParseResult<OptionDefinition> argParseResult,
    final Map<String, String>? env,
    final RunCommandContext<OptionDefinition, T>? prevContext,
    final ContextProvider? provider,
  ) {
    final command = argParseResult.command;
    if (command == null) throw StateError('ArgParseResult.command is null');
    if (command is! AbstractCommand<OptionDefinition, T>) {
      throw StateError(
        'ArgParseResult.command is not an AbstractCommand: ${command.runtimeType}',
      );
    }

    final cmdRunContext = _resolveCmd(
      command,
      argParseResult,
      env,
      prevContext,
      provider,
    );

    if (argParseResult.child case final ArgParseResult child) {
      final next = _resolveNext(child, env, cmdRunContext, provider);
      cmdRunContext.next = next;
    } else {
      cmdRunContext.next = null;
    }

    return cmdRunContext;
  }

  RunCommandContext<P, T> _resolveCmd<P extends OptionDefinition>(
    final AbstractCommand<P, T> command,
    final ArgParseResult<P> parseResult,
    final Map<String, String>? env,
    final RunCommandContext<OptionDefinition, T>? prevContext,
    final ContextProvider? provider,
  ) {
    final Configuration<P> config = command.resolveCommandConfiguration(
      parsedArgs: NewParsedArgs(parseResult),
      env: env,
      configBroker: configBroker,
      ignoreUnexpectedPositionalArgs: ignoreUnexpectedPositionalArgs,
    );

    return command.buildRunContext(
      config,
      prevContext,
      provider,
    );
  }

  void _throwIfConfigurationErrors(
    final RunCommandContext<OptionDefinition, T> runContexts,
    final ArgParseResult<OptionDefinition> argParseResult,
  ) {
    final messages = <String>[];
    AbstractCommand? firstCommandWithErrors;

    RunCommandContext? context = runContexts;
    ArgParseResult? parsed = argParseResult;
    while (context != null) {
      final name = context.command.name;
      final parserErrors = parsed?.errors.map(
        (final error) => '$name: ${formatConfigError(error)}',
      );
      final resolutionErrors = context.config.errors.map(
        (final error) => '$name: ${formatConfigError(error)}',
      );
      final errors = [...?parserErrors, ...resolutionErrors];
      if (errors.isNotEmpty) {
        messages.addAll(errors);
        firstCommandWithErrors ??= context.command;
      }

      context = context.next;
      parsed = parsed?.child;
    }

    if (firstCommandWithErrors != null) {
      throw CommandUsageException(messages.join('\n'), firstCommandWithErrors);
    }
  }

  bool _helpOptionSpecified(
    final RunCommandContext<OptionDefinition, T> runContexts,
  ) {
    // The builtin help option can have been specified via its object
    // or via BuiltinGlobalOption enum, handle both cases.
    // If the user has specified a different help option, return false,
    // allowing a fully custom help behavior.
    final helpOption = runContexts.config.findOption(
      argName: 'help',
    );
    if (helpOption != null &&
        helpOption.option == CommandRunnerBuiltinOptions.help) {
      return runContexts.config.value(
        helpOption as OptionDefinition<bool>,
      );
    }
    return false;
  }

  /// Runs the commands on the command line as one nested middleware chain.
  ///
  /// The first command's middleware is the outermost span. Each following
  /// command's middleware runs inside the previous command's middleware.
  /// Only the last command's [run] is invoked.
  FutureOr<T?> _runCommandLine(
    final RunCommandContext<OptionDefinition, T> runContexts,
  ) {
    return _runNested(runContexts);
  }

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

typedef CommandRunnerHandler<O extends OptionDefinition, T> =
    FutureOr<T?> Function(
      RunCommandContext<OptionDefinition, T> runContexts,
    );

typedef CommandRunnerMiddleware<O extends OptionDefinition, T> =
    CommandRunnerHandler<O, T> Function(
      CommandRunnerHandler<O, T> next,
    );

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
