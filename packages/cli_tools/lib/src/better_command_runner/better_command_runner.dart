import 'dart:async';
import 'dart:io' show Platform;

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:config/config.dart';

import 'completion/completion_command.dart';
import 'completion/completion_tool.dart' show CompletionScript;

/// A function type for executing code before running a command.
typedef OnBeforeRunCommand = Future<void> Function(BetterCommandRunner runner);

/// A proxy for user-provided functions for passing specific log messages.
///
/// It is valid to not provide a function in order to not pass that output.
final class MessageOutput {
  final void Function(String usage)? usageLogger;
  final void Function(UsageException exception)? usageExceptionLogger;

  const MessageOutput({
    this.usageLogger,
    this.usageExceptionLogger,
  });

  /// Logs a usage exception.
  /// If the function has not been provided then nothing will happen.
  void logUsageException(final UsageException exception) {
    usageExceptionLogger?.call(exception);
  }

  /// Logs a usage message.
  /// If the function has not been provided then nothing will happen.
  void logUsage(final String usage) {
    usageLogger?.call(usage);
  }
}

/// A function type for setting the log level.
/// The [logLevel] is the log level to set.
/// The [commandName] is the name of the command if custom rules for log
/// levels are needed.
typedef SetLogLevel = void Function({
  required CommandRunnerLogLevel parsedLogLevel,
  String? commandName,
});

/// A function type for tracking events.
typedef OnAnalyticsEvent = void Function(String event);

/// A dummy to replicate the usage-text of upstream private `HelpCommand`
final class _HelpCommandDummy extends Command {
  _HelpCommandDummy({required this.runner});

  static const label = 'help';

  static const Null exitCode = null;

  @override
  final name = _HelpCommandDummy.label;

  @override
  final BetterCommandRunner runner;

  @override
  String get description =>
      'Display help information for ${runner.executableName}.';

  @override
  String get invocation => '${runner.executableName} $name [command]';

  @override
  Never run() => throw StateError(
      'This class is meant to only obtain the Usage Text for `$name` command');
}

/// An extension of [CommandRunner] with additional features.
///
/// This class extends the [CommandRunner] class from the `args` package and adds
/// additional functionality such as logging, setting log levels, tracking events,
/// and handling analytics.
///
/// The [BetterCommandRunner] class uses the config library to provide
/// a more enhanced command line interface for running commands and handling
/// command line arguments, environment variables, and configuration.
class BetterCommandRunner<O extends OptionDefinition, T>
    extends CommandRunner<T> {
  /// Process exit code value for command not found -
  /// The specified command was not found or couldn't be located.
  static const int exitCodeCommandNotFound = 127;

  final MessageOutput? _messageOutput;
  final SetLogLevel? _setLogLevel;
  final OnBeforeRunCommand? _onBeforeRunCommand;
  final OnAnalyticsEvent? _onAnalyticsEvent;
  bool _analyticsEnabled;

  /// The environment variables used for configuration resolution.
  final Map<String, String> envVariables;

  /// The global option definitions.
  late final List<O> _globalOptions;

  Configuration<O>? _globalConfiguration;

  /// The current global configuration.
  Configuration<O> get globalConfiguration {
    final globalConfig = _globalConfiguration;
    if (globalConfig == null) {
      throw StateError('Global configuration is not initialized');
    }
    return globalConfig;
  }

  /// Sets the global configuration, by default called by [parse].
  /// It must be set before [runCommand] is called.
  set globalConfiguration(final Configuration<O> configuration) {
    _globalConfiguration = configuration;
  }

  /// Creates a new instance of [BetterCommandRunner].
  ///
  /// - [executableName] is the name of the executable for the command line interface.
  /// - [description] is a description of the command line interface.
  /// - [messageOutput] is an optional [MessageOutput] object used to pass specific log messages.
  /// - [setLogLevel] function is used to set the log level.
  /// - [onBeforeRunCommand] function is executed before running a command.
  /// - [onAnalyticsEvent] function is used to track events.
  /// - [wrapTextColumn] is the column width for wrapping text in the command line interface.
  /// - [globalOptions] is an optional list of global options.
  /// - [env] is an optional map of environment variables. If not set then
  ///   [Platform.environment] will be used.
  ///
  /// ## Message Output
  ///
  /// The [MessageOutput] object is used to control how specific log messages
  /// are output within this library.
  /// By default regular (non-error) usage is printed to the console,
  /// while UsageExceptions not printed by this library and simply
  /// propagated to the caller, i.e. the same behavior as the `args` package.
  ///
  /// ## Global Options
  ///
  /// If [globalOptions] is not provided then the default global options will be used.
  /// If no global options are desired then an empty list can be provided.
  ///
  /// To define a bespoke set of global options, it is recommended to define
  /// a proper options enum. It can included any of the default global options
  /// as well as any custom options. Example:
  ///
  /// ```dart
  /// enum BespokeGlobalOption<V> implements OptionDefinition<V> {
  ///   quiet(BetterCommandRunnerFlags.quietOption),
  ///   verbose(BetterCommandRunnerFlags.verboseOption),
  ///   analytics(BetterCommandRunnerFlags.analyticsOption),
  ///   name(StringOption(
  ///     argName: 'name',
  ///     allowedValues: ['serverpod', 'stockholm'],
  ///     defaultsTo: 'serverpod',
  ///   )),
  ///   age(IntOption(argName: 'age', helpText: 'Required age', min: 0, max: 100));
  ///
  ///   const BespokeGlobalOption(this.option);
  ///
  ///   @override
  ///   final ConfigOptionBase<V> option;
  /// }
  /// ```
  BetterCommandRunner(
    super.executableName,
    super.description, {
    super.suggestionDistanceLimit,
    final MessageOutput? messageOutput =
        const MessageOutput(usageLogger: print),
    final SetLogLevel? setLogLevel,
    final OnBeforeRunCommand? onBeforeRunCommand,
    final OnAnalyticsEvent? onAnalyticsEvent,
    final int? wrapTextColumn,
    final bool enableCompletionCommand = false,
    final Iterable<CompletionScript>? embeddedCompletions,
    final List<O>? globalOptions,
    final Map<String, String>? env,
  })  : _messageOutput = messageOutput,
        _setLogLevel = setLogLevel,
        _onBeforeRunCommand = onBeforeRunCommand,
        _onAnalyticsEvent = onAnalyticsEvent,
        _analyticsEnabled = onAnalyticsEvent != null,
        envVariables = env ?? Platform.environment,
        super(
          usageLineLength: wrapTextColumn,
        ) {
    if (globalOptions != null) {
      _globalOptions = globalOptions;
    } else if (O == OptionDefinition || O == StandardGlobalOption) {
      _globalOptions = <O>[
        StandardGlobalOption.quiet as O,
        StandardGlobalOption.verbose as O,
        if (this.onAnalyticsEvent != null) StandardGlobalOption.analytics as O,
      ];
    } else {
      throw ArgumentError(
        'globalOptions not provided and O is not assignable from StandardGlobalOption: $O',
      );
    }
    prepareOptionsForParsing(_globalOptions, argParser);

    if (enableCompletionCommand) {
      addCommand(
        CompletionCommand<T>(embeddedCompletions: embeddedCompletions),
      );
    }
  }

  /// The global option definitions.
  List<O> get globalOptions => _globalOptions;

  /// The [MessageOutput] for the command runner.
  /// It is also used for the commands unless they have their own.
  MessageOutput? get messageOutput => _messageOutput;

  /// Adds a list of commands to the command runner.
  void addCommands(final List<Command<T>> commands) {
    for (final command in commands) {
      addCommand(command);
    }
  }

  /// Checks if analytics is enabled.
  /// Note that the return value may change after the [run] method has started.
  /// Can be overridden.
  bool analyticsEnabled() => _analyticsEnabled;

  /// Gets the [onAnalyticsEvent] callback, if set.
  OnAnalyticsEvent? get onAnalyticsEvent => _onAnalyticsEvent;

  /// Sends an analytics event, provided the analytics are enabled.
  /// Invoked from BetterCommandRunner upon command execution
  /// with the event name, or command name if applicable.
  /// Can be overridden to customize the event sending behavior.
  void sendAnalyticsEvent(final String event) {
    if (analyticsEnabled()) {
      try {
        onAnalyticsEvent?.call(event);
      } catch (_) {
        // Silently ignore analytics sending errors to not disrupt the main flow
      }
    }
  }

  /// Determines the analytics settings based on configuration / settings.
  /// Called from [run] before any analytics events are sent and before any
  /// command is run.
  ///
  /// [globalConfiguration] is set before this method is called.
  ///
  /// By default it checks whether the [onAnalyticsEvent] callback is set
  /// and the `--analytics` option.
  /// Subclasses can override this method to customize the behavior,
  /// e.g. to ask the user for permission.
  Future<bool> determineAnalyticsSettings() async {
    if (onAnalyticsEvent == null) {
      return false;
    }

    if (globalConfiguration.findValueOf(
            argName: BetterCommandRunnerFlags.analytics) ==
        false) {
      return false;
    }

    return true;
  }

  /// Parses [args] and invokes [Command.run] on the chosen command.
  ///
  /// This always returns a [Future] in case the command is asynchronous. The
  /// [Future] will throw a [UsageException] if [args] was invalid.
  ///
  /// This overrides the [CommandRunner.run] method in order to resolve the
  /// global configuration before invoking [runCommand].
  /// If this method is overridden, the overriding method must ensure that
  /// the global configuration is set, see [globalConfiguration].
  @override
  Future<T?> run(final Iterable<String> args) {
    return Future.sync(() async {
      final argResults = parse(args);
      globalConfiguration = resolveConfiguration(argResults);

      try {
        _analyticsEnabled = await determineAnalyticsSettings();

        if (globalConfiguration.errors.isNotEmpty) {
          final buffer = StringBuffer();
          final errors = globalConfiguration.errors.map(formatConfigError);
          buffer.writeAll(errors, '\n');
          usageException(buffer.toString());
        }
      } on UsageException catch (e) {
        messageOutput?.logUsageException(e);
        sendAnalyticsEvent(BetterCommandRunnerAnalyticsEvents.invalid);
        rethrow;
      }

      return runCommand(argResults);
    });
  }

  /// Parses the command line arguments and returns the result.
  @override
  ArgResults parse(final Iterable<String> args) {
    try {
      return super.parse(args);
    } on UsageException catch (e) {
      messageOutput?.logUsageException(e);
      sendAnalyticsEvent(BetterCommandRunnerAnalyticsEvents.invalid);
      rethrow;
    }
  }

  @override
  void printUsage() {
    messageOutput?.logUsage(usage);
  }

  /// Runs the command specified by [topLevelResults].
  ///
  /// [globalConfiguration] is set before this method is called.
  ///
  /// This is notionally a protected method. It may be overridden or called from
  /// subclasses, but it shouldn't be called externally.
  ///
  /// It's useful to override this to handle global flags and/or wrap the entire
  /// command in a block. For example, you might handle the `--verbose` flag
  /// here to enable verbose logging before running the command.
  ///
  /// This returns the return value of [Command.run].
  @override
  Future<T?> runCommand(final ArgResults topLevelResults) async {
    _setLogLevel?.call(
      parsedLogLevel: _determineLogLevel(globalConfiguration),
      commandName: topLevelResults.command?.name,
    );

    unawaited(
      Future.sync(() {
        final command = topLevelResults.command;
        if (command != null) {
          // Command name can only be null for top level results.
          // But since we are taking the name of a command from the top level
          // results there should always be a name specified.
          assert(command.name != null, 'Command name should never be null.');
          sendAnalyticsEvent(
            command.name ?? BetterCommandRunnerAnalyticsEvents.invalid,
          );
          return;
        }

        // Checks if the command is valid (i.e. no unexpected arguments).
        // If there are unexpected arguments this will trigger a [UsageException]
        // which will be caught in the try catch around the super.runCommand call.
        // Therefore, this ensures that the help event is not sent for
        // commands that are invalid.
        // Note that there are other scenarios that also trigger a [UsageException]
        // so the try/catch statement can't be fully compensated for handled here.
        final noUnexpectedArgs = topLevelResults.rest.isEmpty;
        if (noUnexpectedArgs) {
          sendAnalyticsEvent(BetterCommandRunnerAnalyticsEvents.help);
        }
      }),
    );

    await _onBeforeRunCommand?.call(this);

    try {
      if (_isUsageOfHelpCommandRequested(topLevelResults)) {
        messageOutput?.logUsage(_HelpCommandDummy(runner: this).usage);
        return _HelpCommandDummy.exitCode;
      }
      return await super.runCommand(topLevelResults);
    } on UsageException catch (e) {
      messageOutput?.logUsageException(e);
      sendAnalyticsEvent(BetterCommandRunnerAnalyticsEvents.invalid);
      rethrow;
    }
  }

  /// Resolves the global configuration for this command runner.
  ///
  /// This method can be overridden to change the configuration resolution
  /// behavior.
  Configuration<O> resolveConfiguration(final ArgResults? argResults) {
    return Configuration.resolveNoExcept(
      options: _globalOptions,
      argResults: argResults,
      env: envVariables,
      ignoreUnexpectedPositionalArgs: true,
    );
  }

  static bool _isUsageOfHelpCommandRequested(final ArgResults topLevelResults) {
    // check whether Help Command is chosen
    final topLevelCommand = topLevelResults.command;
    if (topLevelCommand == null) {
      return false;
    }
    if (topLevelCommand.name != _HelpCommandDummy.label) {
      return false;
    }
    final helpCommand = topLevelCommand;
    // check whether it's allowed to get the usage-text for `help`
    if (!helpCommand.options.contains(_HelpCommandDummy.label)) {
      throw StateError('Upstream `package:args` has a breaking change');
    }
    // case: `mock help -h`
    if (helpCommand.flag(_HelpCommandDummy.label)) {
      return true;
    }
    // case: `mock help help`
    if ((helpCommand.arguments.contains(_HelpCommandDummy.label))) {
      return true;
    }
    // aside: more cases may be added if necessary in future
    return false;
  }

  static CommandRunnerLogLevel _determineLogLevel(final Configuration config) {
    if (config.findValueOf(argName: BetterCommandRunnerFlags.verbose) == true) {
      return CommandRunnerLogLevel.verbose;
    } else if (config.findValueOf(argName: BetterCommandRunnerFlags.quiet) ==
        true) {
      return CommandRunnerLogLevel.quiet;
    }

    return CommandRunnerLogLevel.normal;
  }
}

/// Constants for the command runner flags.
abstract class BetterCommandRunnerFlags {
  static const quiet = 'quiet';
  static const quietAbbr = 'q';
  static const verbose = 'verbose';
  static const verboseAbbr = 'v';
  static const analytics = 'analytics';
  static const analyticsAbbr = 'a';

  static const quietOption = FlagOption(
    argName: quiet,
    argAbbrev: quietAbbr,
    defaultsTo: false,
    negatable: false,
    helpText: 'Suppress all cli output. Is overridden by '
        ' -$verboseAbbr, --$verbose.',
  );

  static const verboseOption = FlagOption(
    argName: verbose,
    argAbbrev: verboseAbbr,
    defaultsTo: false,
    negatable: false,
    helpText: 'Prints additional information useful for development. '
        'Overrides --$quietAbbr, --$quiet.',
  );

  static const analyticsOption = FlagOption(
    argName: analytics,
    argAbbrev: analyticsAbbr,
    defaultsTo: true,
    negatable: true,
    helpText: 'Toggles if analytics data is sent. ',
  );
}

enum StandardGlobalOption<V extends Object> implements OptionDefinition<V> {
  quiet(BetterCommandRunnerFlags.quietOption),
  verbose(BetterCommandRunnerFlags.verboseOption),
  analytics(BetterCommandRunnerFlags.analyticsOption);

  const StandardGlobalOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

/// Constants for the command runner analytics events.
abstract class BetterCommandRunnerAnalyticsEvents {
  static const help = 'help';
  static const invalid = 'invalid';
}

/// An enum for the command runner log levels.
enum CommandRunnerLogLevel { quiet, verbose, normal }
