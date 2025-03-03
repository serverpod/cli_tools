import 'dart:async';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

/// A function type for executing code before running a command.
typedef OnBeforeRunCommand = Future<void> Function(BetterCommandRunner runner);

/// A proxy for user-provided functions for passing specific log messages.
///
/// It is valid to not provide a function in order to not pass that output.
final class MessageOutput {
  final void Function(UsageException exception)? _logUsageException;

  final void Function(String usage)? _logUsage;

  MessageOutput({
    void Function(UsageException exception)? logUsageException,
    void Function(String usage)? logUsage,
  })  : _logUsageException = logUsageException,
        _logUsage = logUsage;

  /// Logs a usage exception.
  /// If the function has not been provided then nothing will happen.
  void logUsageException(UsageException exception) {
    _logUsageException?.call(exception);
  }

  /// Logs a usage message.
  /// If the function has not been provided then nothing will happen.
  void logUsage(String usage) {
    _logUsage?.call(usage);
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
class BetterCommandRunner extends CommandRunner {
  /// Process exit code value for command not found -
  /// The specified command was not found or couldn't be located.
  static const int exitCodeCommandNotFound = 127;

  final MessageOutput? _messageOutput;
  final SetLogLevel? _setLogLevel;
  final OnBeforeRunCommand? _onBeforeRunCommand;
  OnAnalyticsEvent? _onAnalyticsEvent;

  final ArgParser _argParser;

  /// Creates a new instance of [BetterCommandRunner].
  ///
  /// - [executableName] is the name of the executable for the command line interface.
  /// - [description] is a description of the command line interface.
  /// - [messageOutput] is an optional [MessageOutput] object used to pass specific log messages.
  /// - [setLogLevel] function is used to set the log level.
  /// - [onBeforeRunCommand] function is executed before running a command.
  /// - [onAnalyticsEvent] function is used to track events.
  /// - [wrapTextColumn] is the column width for wrapping text in the command line interface.
  BetterCommandRunner(
    super.executableName,
    super.description, {
    MessageOutput? messageOutput,
    SetLogLevel? setLogLevel,
    OnBeforeRunCommand? onBeforeRunCommand,
    OnAnalyticsEvent? onAnalyticsEvent,
    int? wrapTextColumn,
  })  : _messageOutput = messageOutput,
        _setLogLevel = setLogLevel,
        _onBeforeRunCommand = onBeforeRunCommand,
        _onAnalyticsEvent = onAnalyticsEvent,
        _argParser = ArgParser(usageLineLength: wrapTextColumn) {
    argParser.addFlag(
      BetterCommandRunnerFlags.quiet,
      abbr: BetterCommandRunnerFlags.quietAbbr,
      defaultsTo: false,
      negatable: false,
      help: 'Suppress all cli output. Is overridden by '
          ' -${BetterCommandRunnerFlags.verboseAbbr}, --${BetterCommandRunnerFlags.verbose}.',
    );

    argParser.addFlag(
      BetterCommandRunnerFlags.verbose,
      abbr: BetterCommandRunnerFlags.verboseAbbr,
      defaultsTo: false,
      negatable: false,
      help: 'Prints additional information useful for development. '
          'Overrides --${BetterCommandRunnerFlags.quietAbbr}, --${BetterCommandRunnerFlags.quiet}.',
    );

    if (_onAnalyticsEvent != null) {
      argParser.addFlag(
        BetterCommandRunnerFlags.analytics,
        abbr: BetterCommandRunnerFlags.analyticsAbbr,
        defaultsTo: true,
        negatable: true,
        help: 'Toggles if analytics data is sent. ',
      );
    }
  }

  @override
  ArgParser get argParser => _argParser;

  /// Adds a list of commands to the command runner.
  void addCommands(List<Command> commands) {
    for (var command in commands) {
      addCommand(command);
    }
  }

  /// Checks if analytics is enabled.
  bool analyticsEnabled() => _onAnalyticsEvent != null;

  @override
  ArgResults parse(Iterable<String> args) {
    try {
      return super.parse(args);
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

  @override
  Future<void> runCommand(ArgResults topLevelResults) async {
    _setLogLevel?.call(
      parsedLogLevel: _parseLogLevel(topLevelResults),
      commandName: topLevelResults.command?.name,
    );

    if (argParser.options.containsKey(BetterCommandRunnerFlags.analytics) &&
        !topLevelResults.flag(BetterCommandRunnerFlags.analytics)) {
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
      await super.runCommand(topLevelResults);
    } on UsageException catch (e) {
      _messageOutput?.logUsageException(e);
      _onAnalyticsEvent?.call(BetterCommandRunnerAnalyticsEvents.invalid);
      rethrow;
    }
  }

  CommandRunnerLogLevel _parseLogLevel(ArgResults topLevelResults) {
    if (topLevelResults[BetterCommandRunnerFlags.verbose]) {
      return CommandRunnerLogLevel.verbose;
    } else if (topLevelResults[BetterCommandRunnerFlags.quiet]) {
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
}

/// Constants for the command runner analytics events.
abstract class BetterCommandRunnerAnalyticsEvents {
  static const help = 'help';
  static const invalid = 'invalid';
}

/// An enum for the command runner log levels.
enum CommandRunnerLogLevel { quiet, verbose, normal }
