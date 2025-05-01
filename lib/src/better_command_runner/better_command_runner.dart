import 'dart:async';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_tools/config.dart';
import 'package:cli_tools/src/better_command_runner/config_resolver.dart';

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
  void logUsageException(UsageException exception) {
    usageExceptionLogger?.call(exception);
  }

  /// Logs a usage message.
  /// If the function has not been provided then nothing will happen.
  void logUsage(String usage) {
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

/// A custom implementation of [CommandRunner] with additional features.
///
/// This class extends the [CommandRunner] class from the `args` package and adds
/// additional functionality such as logging, setting log levels, tracking events,
/// and handling analytics.
///
/// The [BetterCommandRunner] class provides a more enhanced command line interface
/// for running commands and handling command line arguments.
class BetterCommandRunner<O extends OptionDefinition, T>
    extends CommandRunner<T> {
  static const foo = <OptionDefinition>[
    BetterCommandRunnerFlags.verboseOption,
    BetterCommandRunnerFlags.quietOption,
  ];

  /// Process exit code value for command not found -
  /// The specified command was not found or couldn't be located.
  static const int exitCodeCommandNotFound = 127;

  final MessageOutput? _messageOutput;
  final SetLogLevel? _setLogLevel;
  final OnBeforeRunCommand? _onBeforeRunCommand;
  OnAnalyticsEvent? _onAnalyticsEvent;

  /// The gloabl option definitions.
  late final List<O> _globalOptions;

  /// The resolver for the global configuration.
  final ConfigResolver<O> _configResolver;

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
  set globalConfiguration(Configuration<O> configuration) {
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
  /// - [configResolver] is an optional custom [ConfigResolver] implementation.
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
  ///
  /// If [configResolver] is not provided then [DefaultConfigResolver] will be used,
  /// which uses the command line arguments and environment variables as input sources.
  BetterCommandRunner(
    super.executableName,
    super.description, {
    super.suggestionDistanceLimit,
    MessageOutput? messageOutput = const MessageOutput(usageLogger: print),
    SetLogLevel? setLogLevel,
    OnBeforeRunCommand? onBeforeRunCommand,
    OnAnalyticsEvent? onAnalyticsEvent,
    int? wrapTextColumn,
    List<O>? globalOptions,
    ConfigResolver<O>? configResolver,
  })  : _messageOutput = messageOutput,
        _setLogLevel = setLogLevel,
        _onBeforeRunCommand = onBeforeRunCommand,
        _onAnalyticsEvent = onAnalyticsEvent,
        _configResolver = configResolver ?? DefaultConfigResolver<O>(),
        super(
          usageLineLength: wrapTextColumn,
        ) {
    if (globalOptions != null) {
      _globalOptions = globalOptions;
    } else if (_onAnalyticsEvent != null) {
      _globalOptions = BasicGlobalOption.values as List<O>;
    } else {
      _globalOptions = [
        BasicGlobalOption.quiet as O,
        BasicGlobalOption.verbose as O,
      ];
    }
    prepareOptionsForParsing(_globalOptions, argParser);
  }

  /// Adds a list of commands to the command runner.
  void addCommands(List<Command<T>> commands) {
    for (var command in commands) {
      addCommand(command);
    }
  }

  /// Checks if analytics is enabled.
  bool analyticsEnabled() => _onAnalyticsEvent != null;

  /// Parses the command line arguments and returns the result.
  ///
  /// This method overrides the [CommandRunner.parse] method to resolve the
  /// global configuration before returning the result.
  ///
  /// If this method is overridden, the caller is responsible for
  /// ensuring the global configuration is set, see [globalConfiguration].
  @override
  ArgResults parse(Iterable<String> args) {
    try {
      var argResults = super.parse(args);
      globalConfiguration = resolveConfiguration(argResults);
      return argResults;
    } on UsageException catch (e) {
      _messageOutput?.logUsageException(e);
      _onAnalyticsEvent?.call(BetterCommandRunnerAnalyticsEvents.invalid);
      rethrow;
    }
  }

  @override
  void printUsage() {
    _messageOutput?.logUsage(usage);
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
  Future<T?> runCommand(ArgResults topLevelResults) async {
    _setLogLevel?.call(
      parsedLogLevel: _determineLogLevel(globalConfiguration),
      commandName: topLevelResults.command?.name,
    );

    if (globalConfiguration.findValueOf(
            argName: BetterCommandRunnerFlags.analytics) ==
        false) {
      _onAnalyticsEvent = null;
    }

    unawaited(
      Future(() async {
        var command = topLevelResults.command;
        if (command != null) {
          // Command name can only be null for top level results.
          // But since we are taking the name of a command from the top level
          // results there should always be a name specified.
          assert(command.name != null, 'Command name should never be null.');
          _onAnalyticsEvent?.call(
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
        var noUnexpectedArgs = topLevelResults.rest.isEmpty;
        if (noUnexpectedArgs) {
          _onAnalyticsEvent?.call(BetterCommandRunnerAnalyticsEvents.help);
        }
      }),
    );

    await _onBeforeRunCommand?.call(this);

    try {
      return super.runCommand(topLevelResults);
    } on UsageException catch (e) {
      _messageOutput?.logUsageException(e);
      _onAnalyticsEvent?.call(BetterCommandRunnerAnalyticsEvents.invalid);
      rethrow;
    }
  }

  /// Resolves the global configuration for this command runner
  /// using the preset [ConfigResolver].
  /// If there are errors resolving the configuration,
  /// a UsageException is thrown with appropriate error messages.
  ///
  /// This method can be overridden to change the configuration resolution
  /// or error handling behavior.
  Configuration<O> resolveConfiguration(ArgResults? argResults) {
    final config = _configResolver.resolveConfiguration(
      options: _globalOptions,
      argResults: argResults,
    );

    if (config.errors.isNotEmpty) {
      final buffer = StringBuffer();
      final errors = config.errors.map(formatConfigError);
      buffer.writeAll(errors, '\n');
      usageException(buffer.toString());
    }

    return config;
  }

  static CommandRunnerLogLevel _determineLogLevel(Configuration config) {
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

enum BasicGlobalOption<V> implements OptionDefinition<V> {
  quiet(BetterCommandRunnerFlags.quietOption),
  verbose(BetterCommandRunnerFlags.verboseOption),
  analytics(BetterCommandRunnerFlags.analyticsOption);

  const BasicGlobalOption(this.option);

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
