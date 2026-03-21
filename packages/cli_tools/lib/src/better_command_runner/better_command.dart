import 'dart:async' show FutureOr;
import 'dart:collection' show UnmodifiableMapView;
import 'dart:io' show Platform;

import 'package:args/args.dart';
import 'package:config/config.dart';

import 'better_command_runner.dart';
import 'usage.dart';

/// An improved alternative to the args package's [Command] with additional features.
///
/// A command is known as a "leaf command" if it has no subcommands and is meant
/// to be run. Leaf commands must override [resolveAndRun].
///
/// A command with subcommands is known as a "branch command" and cannot be run
/// itself. It should call [addSubcommand] (often from the constructor) to
/// register subcommands.
///
/// The [BetterCommand] class uses the config library to provide
/// a more enhanced command line interface for running commands and handling
/// command line arguments, environment variables, and configuration.
abstract class BetterCommand<O extends OptionDefinition, T> {
  /// The name of this command.
  String get name;

  /// A description of this command, included in [usage].
  String get description;

  /// A short description of this command, included in [parent]'s
  /// [CommandRunner.usage].
  ///
  /// This defaults to the first line of [description].
  String get summary => description.split('\n').first;

  /// The command's category.
  ///
  /// Displayed in [parent]'s [CommandRunner.usage]. Commands with categories
  /// will be grouped together, and displayed after commands without a category.
  String get category => '';

  /// A single-line template for how to invoke this command (e.g. `"pub get
  /// `package`"`).
  String get invocation {
    final parents = [name];
    for (var command = parent; command != null; command = command.parent) {
      parents.add(command.name);
    }
    parents.add(runner!.executableName);

    final invocation = parents.reversed.join(' ');
    return _subcommands.isNotEmpty
        ? '$invocation <subcommand> [arguments]'
        : '$invocation [arguments]';
  }

  /// Generates a string displaying usage information for this command.
  ///
  /// This includes usage for the command's arguments as well as a list of
  /// subcommands, if there are any.
  String get usage =>
      wrapText('$description\n\n', length: _usageLineLength) +
      _usageWithoutDescription;

  /// An optional footer for [usage].
  ///
  /// If a subclass overrides this to return a string, it will automatically be
  /// added to the end of [usage].
  String? get usageFooter => null;

  /// Returns [usage] with [description] removed from the beginning.
  String get _usageWithoutDescription {
    final length = _usageLineLength;
    const usagePrefix = 'Usage: ';
    final buffer = StringBuffer()
      ..writeln(usagePrefix +
          wrapText(invocation,
              length: _usageLineLength, hangingIndent: usagePrefix.length))
      ..writeln(_argParser.usage);

    if (_subcommands.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(getCommandUsage(
        _subcommands,
        isSubcommand: true,
        lineLength: length,
      ));
    }

    buffer.writeln();
    buffer.write(wrapText(
        'Run "${runner!.executableName} help" to see global options.',
        length: _usageLineLength,
        hangingIndent: null));

    if (usageFooter != null) {
      buffer.writeln();
      buffer.write(wrapText(usageFooter!,
          length: _usageLineLength, hangingIndent: null));
    }

    return buffer.toString();
  }

  /// An unmodifiable view of all sublevel commands of this command.
  Map<String, BetterCommand<OptionDefinition, T>> get subcommands =>
      UnmodifiableMapView(_subcommands);
  final _subcommands = <String, BetterCommand<OptionDefinition, T>>{};

  /// Whether or not this command should be hidden from help listings.
  ///
  /// This is intended to be overridden by commands that want to mark themselves
  /// hidden.
  ///
  /// By default, leaf commands are always visible. Branch commands are visible
  /// as long as any of their leaf commands are visible.
  bool get hidden {
    // Leaf commands are visible by default.
    if (_subcommands.isEmpty) return false;

    // Otherwise, a command is hidden if all of its subcommands are.
    return _subcommands.values.every((final subcommand) => subcommand.hidden);
  }

  /// Whether or not this command takes positional arguments in addition to
  /// options.
  ///
  /// If false, [CommandRunner.run] will throw a [UsageException] if arguments
  /// are provided. Defaults to true.
  ///
  /// This is intended to be overridden by commands that don't want to receive
  /// arguments. It has no effect for branch commands.
  bool get takesArguments => true;

  /// Alternate names for this command.
  ///
  /// These names won't be used in the documentation, but they will work when
  /// invoked on the command line.
  ///
  /// This is intended to be overridden.
  List<String> get aliases => const [];

  /// Alternate non-functional names for this command.
  ///
  /// These names won't be used in the documentation, and also they won't work
  /// when invoked on the command line. But if an unknown command is used it
  /// will be matched against this when creating suggestions.
  ///
  /// A name does not have to be repeated both here and in [aliases].
  ///
  /// This is intended to be overridden.
  List<String> get suggestionAliases => const [];

  /// Adds [BetterCommand] as a subcommand of this.
  void addSubcommand(final BetterCommand<OptionDefinition, T> command) {
    final names = [command.name, ...command.aliases];
    for (final name in names) {
      _subcommands[name] = command;
      _argParser.addCommand(name, command._argParser);
    }
    command._parent = this;
  }

  /// Throws a [UsageException] with [message].
  Never usageException(final String message) => throw UsageException(
      wrapText(
        message,
        length: _usageLineLength,
        hangingIndent: null,
      ),
      _usageWithoutDescription);

  //--------------------------------------------------------

  static const _defaultMessageOutput = MessageOutput(usageLogger: print);

  /// An optional maximum line length for [usage] messages.
  /// If null (the default), help messages are not wrapped.
  final int? _usageLineLength;

  final MessageOutput? _messageOutput;
  final ArgParser _argParser;

  /// The option definitions for this command.
  final List<O> options;

  /// Creates a new instance of [BetterCommand].
  ///
  /// - [messageOutput] is an optional [MessageOutput] object used to pass specific log messages.
  /// - [wrapTextColumn] is the column width for wrapping text in the command line interface.
  /// - [options] is a list of options, empty by default.
  /// - [env] is an optional map of environment variables. If not set then
  ///   [Platform.environment] will be used.
  ///
  /// [messageOutput] is optional and will default to the
  /// value of the command runner (if any).
  ///
  /// ## Options
  ///
  /// To define a bespoke set of options, it is recommended to define
  /// a proper options enum. It can included any of the default options
  /// as well as any custom options. Example:
  ///
  /// ```dart
  /// enum BespokeOption<V> implements OptionDefinition<V> {
  ///   name(StringOption(
  ///     argName: 'name',
  ///     allowedValues: ['serverpod', 'stockholm'],
  ///     defaultsTo: 'serverpod',
  ///   )),
  ///   age(IntOption(argName: 'age', helpText: 'Required age', min: 0, max: 100));
  ///
  ///   const BespokeOption(this.option);
  ///
  ///   @override
  ///   final ConfigOptionBase<V> option;
  /// }
  /// ```
  BetterCommand({
    final MessageOutput? messageOutput = _defaultMessageOutput,
    final int? wrapTextColumn,
    this.options = const [],
  })  : _messageOutput = messageOutput,
        _usageLineLength = wrapTextColumn,
        _argParser = ArgParser(usageLineLength: wrapTextColumn) {
    if (!_argParser.allowsAnything) {
      _argParser.addFlag('help',
          abbr: 'h', negatable: false, help: 'Print this usage information.');
    }
    prepareOptionsForParsing(options, _argParser);
  }

  MessageOutput? get messageOutput {
    if (_messageOutput != _defaultMessageOutput) {
      return _messageOutput;
    }
    if (runner case final BetterCommandRunner<O, T> runner) {
      return runner.messageOutput;
    }
    return _messageOutput;
  }

  /// The command's parent command, if this is a subcommand.
  ///
  /// This will be `null` until [addSubcommand] has been called with
  /// this command.
  BetterCommand<OptionDefinition, T>? get parent => _parent;
  BetterCommand<OptionDefinition, T>? _parent;

  /// The command runner for this command.
  ///
  /// This will be `null` until [CommandRunner.addCommand] has been called with
  /// this command or one of its parents.
  BetterCommandRunner<OptionDefinition, T>? get runner {
    if (parent == null) return _runner;
    return parent!.runner;
  }

  void setRunner(final BetterCommandRunner<OptionDefinition, T> runner) {
    if (_runner != null) {
      throw StateError('Runner already set');
    }
    _runner = runner;
  }

  BetterCommandRunner<OptionDefinition, T>? _runner;

  ArgParser get argParser => _argParser;

  /// Prints the usage information for this command.
  ///
  /// This is called internally by [resolveAndRun] and can be overridden by subclasses to
  /// control how output is displayed or integrate with a logging system.
  void printUsage() {
    messageOutput?.logUsage(usage);
  }

  /// Resolves the configuration (args, env, etc) and runs the command
  /// subclass via [run].
  ///
  /// If there are errors resolving the configuration,
  /// a UsageException is thrown with appropriate error messages.
  ///
  /// Subclasses should override [run] instead of this method,
  /// unless they want to handle the configuration resolution themselves.
  FutureOr<T>? resolveAndRun(
      {required final Configuration globalConfiguration,
      required final ArgResults topLevelResults,
      required final ArgResults commandResults,
      required final Map<String, String> env}) {
    final config = resolveConfiguration(commandResults, env);

    if (config.errors.isNotEmpty) {
      final buffer = StringBuffer();
      final errors = config.errors.map(formatConfigError);
      buffer.writeAll(errors, '\n');
      usageException(buffer.toString());
    }

    final runContext = RunContext(
      topLevelResults: topLevelResults,
      commandResults: commandResults,
      globalConfig: globalConfiguration,
      commandConfig: config,
    );
    return run(runContext);
  }

  /// Resolves the configuration for this command.
  ///
  /// This method can be overridden to change the configuration resolution
  /// behavior.
  Configuration<O> resolveConfiguration(
      final ArgResults argResults, final Map<String, String> env) {
    return Configuration.resolveNoExcept(
      options: options,
      argResults: argResults,
      env: env,
    );
  }

  /// Runs this command with the resolved run context.
  /// Subclasses should override this method.
  FutureOr<T>? run(final RunContext<O> runContext) {
    throw UnimplementedError(
        'Leaf command "$name" must implement runWithConfig().');
  }

  @override
  String toString() => 'Command "$name": $summary';
}

class RunContext<O extends OptionDefinition> {
  final ArgResults topLevelResults;
  final ArgResults commandResults;
  final Configuration globalConfig;
  final Configuration<O> commandConfig;

  RunContext({
    required this.topLevelResults,
    required this.commandResults,
    required this.globalConfig,
    required this.commandConfig,
  });
}
