import 'dart:async' show unawaited;
import 'dart:collection' show UnmodifiableMapView;
import 'dart:io' show Platform;

import 'package:args/args.dart';
import 'package:config/config.dart';

import 'analytics/command_properties.dart';
import 'command.dart';
import 'completion/completion_command.dart';
import 'completion/completion_tool.dart' show CompletionScript;
import 'help_command.dart';
import 'help_command_workaround.dart' show HelpCommandWorkaround;
import 'similarity_search.dart';
import 'usage.dart';

/// A function type for executing code before running a command.
typedef OnBeforeRunCommand = Future<void> Function(NewCommandRunner runner);

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

/// An improved alternative to [CommandRunner] from the `args` package, with
/// additional features such as logging, setting log levels, tracking events,
/// and handling analytics.
///
/// The type argument `T` represents the type returned by [NewCommand.resolveAndRun] and
/// [CommandRunner.run]; it can be ommitted if you're not using the return
/// values.
///
/// The [NewCommandRunner] class uses the config library to provide
/// a more enhanced command line interface for running commands and handling
/// command line arguments, environment variables, and configuration.
class NewCommandRunner<O extends OptionDefinition, T> {
  /// Process exit code value for command not found -
  /// The specified command was not found or couldn't be located.
  static const int exitCodeCommandNotFound = 127;

  /// The name of the executable being run.
  ///
  /// Used for error reporting and [usage].
  final String executableName;

  /// A short description of this executable.
  final String description;

  /// A single-line template for how to invoke this executable.
  ///
  /// Defaults to `"$executableName <command> arguments`". Subclasses can
  /// override this for a more specific template.
  String get invocation => '$executableName <command> [arguments]';

  /// Generates a string displaying usage information for the executable.
  ///
  /// This includes usage for the global arguments as well as a list of
  /// top-level commands.
  String get usage =>
      wrapText(
        '$description\n\n',
        length: _argParser.usageLineLength,
        hangingIndent: null,
      ) +
      _usageWithoutDescription;

  /// An optional footer for [usage].
  ///
  /// If a subclass overrides this to return a string, it will automatically be
  /// added to the end of [usage].
  String? get usageFooter => null;

  /// Returns [usage] with [description] removed from the beginning.
  String get _usageWithoutDescription {
    const usagePrefix = 'Usage:';
    final buffer = StringBuffer();
    buffer.writeln(
      '$usagePrefix ${wrapText(invocation, length: _argParser.usageLineLength, hangingIndent: usagePrefix.length)}\n',
    );
    buffer.writeln(
      wrapText(
        'Global options:',
        length: _argParser.usageLineLength,
        hangingIndent: null,
      ),
    );
    buffer.writeln('${_argParser.usage}\n');
    buffer.writeln(
      '${getCommandUsage(_commands, lineLength: _argParser.usageLineLength)}\n',
    );
    buffer.write(
      wrapText(
        'Run "$executableName help <command>" for more information about a '
        'command.',
        length: _argParser.usageLineLength,
        hangingIndent: null,
      ),
    );
    if (usageFooter != null) {
      buffer.write(
        '\n${wrapText(usageFooter!, length: _argParser.usageLineLength, hangingIndent: null)}',
      );
    }
    return buffer.toString();
  }

  /// An unmodifiable view of all top-level commands defined for this runner.
  Map<String, NewCommand<OptionDefinition, T>> get commands =>
      UnmodifiableMapView(_commands);
  final _commands = <String, NewCommand<OptionDefinition, T>>{};

  /// The top-level argument parser.
  ///
  /// Global options should be registered with this parser.
  /// Commands should be registered with [addCommand] rather than directly on the parser.
  ArgParser get argParser => _argParser;
  final ArgParser _argParser;

  /// The maximum edit distance allowed when suggesting possible intended
  /// commands.
  ///
  /// Set to `0` in order to disable suggestions, defaults to `2`.
  final int suggestionDistanceLimit;

  /// Throws a [UsageException] with [message].
  Never usageException(String message) =>
      throw UsageException(message, _usageWithoutDescription);

  /// Adds [NewCommand] as a top-level command to this runner.
  void addCommand(NewCommand<OptionDefinition, T> command) {
    final names = [command.name, ...command.aliases];
    for (final name in names) {
      _commands[name] = command;
      _argParser.addCommand(name, command.argParser);
    }
    command.setRunner(this);
  }

  /// Runs the command specified by [topLevelResults].
  ///
  /// This returns the return value of [NewCommand.resolveAndRun].
  Future<T?> _originalRunCommand(
    Configuration<O> globalConfiguration,
    ArgResults topLevelResults,
    Map<String, String> env,
  ) async {
    var argResults = topLevelResults;
    var commands = _commands;
    NewCommand? command;
    var commandString = executableName;

    while (commands.isNotEmpty) {
      if (argResults.command == null) {
        if (argResults.rest.isEmpty) {
          if (command == null) {
            // No top-level command was chosen.
            printUsage();
            return null;
          }

          command.usageException('Missing subcommand for "$commandString".');
        } else {
          final requested = argResults.rest[0];

          // Build up a help message containing similar commands, if found.
          final similarCommands = similarCommandsText(
            requested,
            commands.values,
          );

          if (command == null) {
            usageException(
              'Could not find a command named "$requested".$similarCommands',
            );
          }

          command.usageException(
            'Could not find a subcommand named '
            '"$requested" for "$commandString".$similarCommands',
          );
        }
      }

      // Step into the command.
      argResults = argResults.command!;
      command = commands[argResults.name]!;
      commands =
          command.subcommands as Map<String, NewCommand<OptionDefinition, T>>;
      commandString += ' ${argResults.name}';

      if (argResults.options.contains('help') && argResults.flag('help')) {
        command.printUsage();
        return null;
      }
    }

    if (topLevelResults.flag('help')) {
      command!.printUsage();
      return null;
    }

    // Make sure there aren't unexpected arguments.
    if (!command!.takesArguments && argResults.rest.isNotEmpty) {
      command.usageException(
        'Command "${argResults.name}" does not take any arguments.',
      );
    }

    return (await command.resolveAndRun(
          globalConfiguration: globalConfiguration,
          topLevelResults: topLevelResults,
          commandResults: argResults,
          env: env,
        ))
        as T?;
  }

  //-------------------------------------------------------------------

  final MessageOutput? _messageOutput;
  final SetLogLevel? _setLogLevel;
  final OnBeforeRunCommand? _onBeforeRunCommand;
  final OnAnalyticsEvent? _onAnalyticsEvent;
  bool _analyticsEnabled;

  /// The global option definitions.
  late final List<O> _globalOptions;

  /// Creates a new instance of [NewCommandRunner].
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
  ///   quiet(NewCommandRunnerFlags.quietOption),
  ///   verbose(NewCommandRunnerFlags.verboseOption),
  ///   analytics(NewCommandRunnerFlags.analyticsOption),
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
  NewCommandRunner(
    this.executableName,
    this.description, {
    this.suggestionDistanceLimit = 2,
    MessageOutput? messageOutput = const MessageOutput(usageLogger: print),
    SetLogLevel? setLogLevel,
    OnBeforeRunCommand? onBeforeRunCommand,
    OnAnalyticsEvent? onAnalyticsEvent,
    int? wrapTextColumn,
    bool enableCompletionCommand = false,
    Iterable<CompletionScript>? embeddedCompletions,
    List<O>? globalOptions,
  }) : _argParser = ArgParser(usageLineLength: wrapTextColumn),
       _messageOutput = messageOutput,
       _setLogLevel = setLogLevel,
       _onBeforeRunCommand = onBeforeRunCommand,
       _onAnalyticsEvent = onAnalyticsEvent,
       _analyticsEnabled = onAnalyticsEvent != null {
    _argParser.addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    );
    addCommand(HelpCommand<T>());

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
    prepareOptionsForParsing(_globalOptions, _argParser);

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
  void addCommands(List<NewCommand<OptionDefinition, T>> commands) {
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
  /// Invoked from NewCommandRunner upon command execution
  /// with the event name, or command name if applicable.
  /// Can be overridden to customize the event sending behavior.
  void sendAnalyticsEvent(
    String event, [
    Map<String, dynamic> properties = const {},
  ]) {
    if (analyticsEnabled()) {
      try {
        onAnalyticsEvent?.call(event, properties);
      } catch (_) {
        // Silently ignore analytics sending errors to not disrupt the main flow
      }
    }
  }

  /// Determines the analytics settings based on configuration / settings.
  /// Called from [run] before any analytics events are sent and before any
  /// command is run.
  ///
  /// By default it checks whether the [onAnalyticsEvent] callback is set
  /// and the `--analytics` option.
  /// Subclasses can override this method to customize the behavior,
  /// e.g. to ask the user for permission.
  Future<bool> determineAnalyticsSettings(
    Configuration<O> globalConfiguration,
  ) async {
    if (onAnalyticsEvent == null) {
      return false;
    }

    if (globalConfiguration.findValueOf(
          argName: NewCommandRunnerFlags.analytics,
        ) ==
        false) {
      return false;
    }

    return true;
  }

  /// Parses [args] and [env] and invokes [NewCommand.resolveAndRun] on the
  /// chosen command.
  ///
  /// This always returns a [Future] in case the command is asynchronous. The
  /// [Future] will throw a [UsageException] if [args] was invalid.
  ///
  /// This resolves the global configuration before invoking [runCommand].
  /// If this method is overridden, the overriding method must ensure that
  /// the global configuration is set, see [globalConfiguration].
  Future<T?> run(Iterable<String> args, {Map<String, String>? env}) {
    final envVars = env ?? Platform.environment;

    return Future.sync(() async {
      final argResults = parse(args);
      final globalConfig = resolveConfiguration(argResults, envVars);

      try {
        _analyticsEnabled = await determineAnalyticsSettings(globalConfig);

        if (globalConfig.errors.isNotEmpty) {
          final buffer = StringBuffer();
          final errors = globalConfig.errors.map(formatConfigError);
          buffer.writeAll(errors, '\n');
          usageException(buffer.toString());
        }
      } on UsageException catch (e) {
        messageOutput?.logUsageException(e);
        sendAnalyticsEvent(NewCommandRunnerAnalyticsEvents.invalid);
        rethrow;
      }

      return runCommand(
        globalConfiguration: globalConfig,
        topLevelResults: argResults,
        env: envVars,
      );
    });
  }

  /// Parses [args] and returns the result, converting an [ArgParserException]
  /// to a [UsageException].
  ArgResults _argParserParse(Iterable<String> args) {
    try {
      return _argParser.parse(args);
    } on ArgParserException catch (error) {
      if (error.commands.isEmpty) usageException(error.message);

      var command = commands[error.commands.first]!;
      for (final commandName in error.commands.skip(1)) {
        command = command.subcommands[commandName]!;
      }

      command.usageException(error.message);
    }
  }

  /// Parses the command line arguments and returns the result.
  ///
  /// Throws a [UsageException] if the arguments are invalid.
  ///
  /// This is notionally a protected method. It may be overridden or called from
  /// subclasses, but it shouldn't be called externally.
  ArgResults parse(Iterable<String> args) {
    try {
      return _argParserParse(args);
    } on UsageException catch (e) {
      messageOutput?.logUsageException(e);
      sendAnalyticsEvent(NewCommandRunnerAnalyticsEvents.invalid);
      rethrow;
    }
  }

  /// Prints the usage information for this runner.
  ///
  /// This is called internally by [run] and can be overridden by subclasses to
  /// control how output is displayed or integrate with a logging system.
  void printUsage() {
    messageOutput?.logUsage(usage);
  }

  /// Runs the command specified by [topLevelResults].
  ///
  /// This is notionally a protected method. It may be overridden or called from
  /// subclasses, but it shouldn't be called externally.
  ///
  /// It's useful to override this to handle global flags and/or wrap the entire
  /// command in a block. For example, you might handle the `--verbose` flag
  /// here to enable verbose logging before running the command.
  ///
  /// This returns the return value of [NewCommand.resolveAndRun].
  Future<T?> runCommand({
    required Configuration<O> globalConfiguration,
    required ArgResults topLevelResults,
    required Map<String, String> env,
  }) async {
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
            command.name!,
            buildCommandPropertiesForAnalytics(
              topLevelResults: topLevelResults,
              argParser: _argParser,
              commands: commands,
            ),
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
          sendAnalyticsEvent(NewCommandRunnerAnalyticsEvents.help);
        }
      }),
    );

    await _onBeforeRunCommand?.call(this);

    try {
      // an edge case regarding `help -h`
      final helpProxy = HelpCommandWorkaround(runner: this);
      if (helpProxy.isUsageOfHelpCommandRequested(topLevelResults)) {
        messageOutput?.logUsage(helpProxy.usage);
        return null;
      }
      // normal cases
      return await _originalRunCommand(
        globalConfiguration,
        topLevelResults,
        env,
      );
    } on UsageException catch (e) {
      messageOutput?.logUsageException(e);
      sendAnalyticsEvent(NewCommandRunnerAnalyticsEvents.invalid);
      rethrow;
    }
  }

  /// Resolves the global configuration for this command runner.
  ///
  /// This method can be overridden to change the configuration resolution
  /// behavior.
  Configuration<O> resolveConfiguration(
    ArgResults argResults,
    Map<String, String> env,
  ) {
    return Configuration.resolveNoExcept(
      options: _globalOptions,
      argResults: argResults,
      env: env,
      ignoreUnexpectedPositionalArgs: true,
    );
  }

  static CommandRunnerLogLevel _determineLogLevel(Configuration config) {
    if (config.findValueOf(argName: NewCommandRunnerFlags.verbose) == true) {
      return CommandRunnerLogLevel.verbose;
    } else if (config.findValueOf(argName: NewCommandRunnerFlags.quiet) ==
        true) {
      return CommandRunnerLogLevel.quiet;
    }

    return CommandRunnerLogLevel.normal;
  }
}

/// Constants for the command runner flags.
abstract class NewCommandRunnerFlags {
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
  quiet(NewCommandRunnerFlags.quietOption),
  verbose(NewCommandRunnerFlags.verboseOption),
  analytics(NewCommandRunnerFlags.analyticsOption)
  ;

  const StandardGlobalOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

/// Constants for the command runner analytics events.
abstract class NewCommandRunnerAnalyticsEvents {
  static const help = 'help';
  static const invalid = 'invalid';
}

/// An enum for the command runner log levels.
enum CommandRunnerLogLevel { quiet, verbose, normal }
