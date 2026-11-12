import 'dart:async';

import 'package:config/command.dart';
import 'package:config/config.dart';

import '../analytics/command_line_properties.dart';

import 'message_output_bridge.dart';

/// A function type for executing code before running a command.
@Deprecated('see addMiddleware instead')
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
typedef SetLogLevel =
    void Function({
      required CommandRunnerLogLevel parsedLogLevel,
      String? commandName,
    });

/// A function type for tracking events.
typedef OnAnalyticsEvent =
    void Function(
      String event,
      Map<String, dynamic> properties,
    );

/// A function type for building command line properties for analytics.
typedef BuildCommandLinePropertiesForAnalytics =
    Map<String, dynamic> Function<O extends OptionDefinition, T>(
      CommandContext<O, T> context,
    );

/// A class to store the analytics enabled value in the [CommandContext].
class AnalyticsEnabled {
  final bool enabled;
  const AnalyticsEnabled(this.enabled);
}

/// An extension of [CommandRunner] with additional features.
///
/// This class extends the [CommandRunner] class from the `config` package and adds
/// additional functionality such as logging, setting log levels, tracking events,
/// and handling analytics.
///
/// The [BetterCommandRunner] class uses the config library to provide
/// a more enhanced command line interface for running commands and handling
/// command line arguments, environment variables, and configuration.
class BetterCommandRunner<O extends OptionDefinition, T>
    extends CommandRunner<O, T> {
  /// Process exit code value for command not found -
  /// The specified command was not found or couldn't be located.
  static const int exitCodeCommandNotFound = 127;

  final MessageOutput? _messageOutput;
  final OnAnalyticsEvent? _onAnalyticsEvent;

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
  ///
  /// ## Message Output
  ///
  /// **The [MessageOutput] object is deprecated, use [usageOutput] instead.**
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
    final UsageOutputHandler? usageOutput,
    super.suggestionDistanceLimit,
    @Deprecated('Use usageOutput instead') final MessageOutput? messageOutput,
    final SetLogLevel? setLogLevel,
    @Deprecated('Use a middleware instead')
    final OnBeforeRunCommand? onBeforeRunCommand,
    final OnAnalyticsEvent? onAnalyticsEvent,
    final BuildCommandLinePropertiesForAnalytics? buildAnalyticsProperties,
    final int? wrapTextColumn,
    @Deprecated('Use completion instead') final bool? enableCompletionCommand,
    @Deprecated('unused') final Iterable<dynamic>? embeddedCompletions,
    final List<O>? globalOptions,
    @Deprecated('unused') final Map<String, String>? env,
    final List<CommandMiddleware<O, T>>? prependMiddlewares,
    final CompletionSettings? completion,
    super.rootFooter,
    super.subcommands,
    super.usageGenerator,
    super.ignoreUnexpectedPositionalArgs,
  }) : _messageOutput = messageOutput,
       _onAnalyticsEvent = onAnalyticsEvent,
       super(
         globalOptions: _makeGlobalOptions(globalOptions, onAnalyticsEvent),
         canRunAsLeafCommand: true, // prints usage when run as leaf command
         usageLineLength: wrapTextColumn,
         usageOutput: _makeUsageOutputHandler(usageOutput, messageOutput),
         completion:
             completion ??
             CompletionSettings(enabled: enableCompletionCommand ?? true),
         middlewares: prependMiddlewares,
       ) {
    this.usageOutput.addUsageExceptionHandler(
      UsageExceptions.simpleHandler(
        (_, _, _) => sendAnalyticsEvent('invalid'),
      ),
    );
    final analyticsPropertiesBuilder =
        buildAnalyticsProperties ?? buildCommandLinePropertiesForAnalytics;
    addMiddleware(
      Middlewares.onBeforeRun((final ctx) async {
        final analyticsEnabled = await determineAnalyticsSettings(ctx);
        ctx.provider.store(AnalyticsEnabled(analyticsEnabled));
        if (analyticsEnabled) {
          final commandName = ctx.next?.command.name ?? ctx.command.name;
          return sendAnalyticsEvent(
            commandName,
            analyticsPropertiesBuilder(ctx),
          );
        }
      }),
    );
    addMiddleware(
      Middlewares.onBeforeRun(
        (final ctx) => setLogLevel?.call(
          parsedLogLevel: _determineLogLevel(ctx.config),
          commandName: ctx.next?.command.name,
        ),
      ),
    );
    if (onBeforeRunCommand case final OnBeforeRunCommand onBeforeRun) {
      addMiddleware(Middlewares.onBeforeRun((final ctx) => onBeforeRun(this)));
    }
  }

  static List<O> _makeGlobalOptions<O extends OptionDefinition>(
    final List<O>? globalOptions,
    final OnAnalyticsEvent? onAnalyticsEvent,
  ) {
    if (globalOptions != null) {
      return globalOptions;
    }
    if (O == OptionDefinition || O == StandardGlobalOption) {
      return <O>[
        StandardGlobalOption.quiet as O,
        StandardGlobalOption.verbose as O,
        if (onAnalyticsEvent != null) StandardGlobalOption.analytics as O,
      ];
    }
    throw ArgumentError(
      'globalOptions not provided and O is not assignable from StandardGlobalOption: $O',
    );
  }

  static UsageOutputHandler _makeUsageOutputHandler(
    final UsageOutputHandler? usageOutput,
    final MessageOutput? messageOutput,
  ) {
    if (usageOutput != null) {
      if (messageOutput != null) {
        throw ArgumentError("Can't provide both usageOutput and messageOutput");
      }
      return usageOutput;
    }

    if (messageOutput == null) return UsageOutputHandler();

    // create a UsageOutputHandler with wrappers around the legacy messageOutput
    return UsageOutputHandler(
      sinks: OutputSinks(out: BridgeUsagePrinter(messageOutput)),
      exceptionSettings: UsageExceptionSettings(
        exceptionPrinter: BridgeUsageExceptionPrinter(messageOutput),
      ),
    );
  }

  /// The [MessageOutput] for the command runner.
  /// It is also used for the commands unless they have their own.
  MessageOutput? get messageOutput => _messageOutput;

  /// Adds a list of commands to the command runner.
  void addCommands(final List<Command<OptionDefinition, T>> commands) {
    for (final command in commands) {
      addSubcommand(command);
    }
  }

  /// Alias for [addSubcommand].
  void addCommand(final Command<OptionDefinition, T> command) {
    addSubcommand(command);
  }

  /// Gets the [onAnalyticsEvent] callback, if set.
  OnAnalyticsEvent? get onAnalyticsEvent => _onAnalyticsEvent;

  /// Sends an analytics event, provided the analytics are enabled.
  /// Invoked from BetterCommandRunner upon command execution
  /// with the event name, or command name if applicable.
  /// Can be overridden to customize the event sending behavior.
  void sendAnalyticsEvent(
    final String event, [
    final Map<String, dynamic> properties = const {},
  ]) {
    try {
      onAnalyticsEvent?.call(event, properties);
    } catch (_) {
      // Silently ignore analytics sending errors to not disrupt the main flow
    }
  }

  /// Determines the analytics settings based on configuration / settings.
  ///
  /// By default it checks whether the [onAnalyticsEvent] callback is set,
  /// that this run is not a completion request,
  /// and the `--analytics` option.
  /// Subclasses can override this method to customize the behavior,
  /// e.g. to ask the user for permission.
  Future<bool> determineAnalyticsSettings(
    final CommandContext<O, T> context,
  ) async {
    if (onAnalyticsEvent == null) return false;

    if (context.isCompletion) return false;

    const name = BetterCommandRunnerFlags.analytics;
    if (context.config.findValueOf(argName: name) == false) {
      return false;
    }
    return true;
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
    helpText:
        'Suppress all cli output. Is overridden by '
        ' -$verboseAbbr, --$verbose.',
  );

  static const verboseOption = FlagOption(
    argName: verbose,
    argAbbrev: verboseAbbr,
    defaultsTo: false,
    negatable: false,
    helpText:
        'Prints additional information useful for development. '
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
