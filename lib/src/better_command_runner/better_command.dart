import 'dart:async' show FutureOr;
import 'dart:io' show Platform;

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_tools/config.dart';

import 'better_command_runner.dart';

/// An extension of [Command] with additional features.
///
/// The [BetterCommand] class uses the config library to provide
/// a more enhanced command line interface for running commands and handling
/// command line arguments, environment variables, and configuration.
abstract class BetterCommand<O extends OptionDefinition, T> extends Command<T> {
  static const _defaultMessageOutput = MessageOutput(usageLogger: print);

  final MessageOutput? _messageOutput;
  final ArgParser _argParser;

  /// The environment variables used for configuration resolution.
  final Map<String, String> envVariables;

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
    MessageOutput? messageOutput = _defaultMessageOutput,
    int? wrapTextColumn,
    this.options = const [],
    Map<String, String>? env,
  })  : _messageOutput = messageOutput,
        _argParser = ArgParser(usageLineLength: wrapTextColumn),
        envVariables = env ?? Platform.environment {
    prepareOptionsForParsing(options, argParser);
  }

  MessageOutput? get messageOutput {
    if (_messageOutput != _defaultMessageOutput) {
      return _messageOutput;
    }
    if (runner case BetterCommandRunner<O, T> runner) {
      return runner.messageOutput;
    }
    return _messageOutput;
  }

  @override
  BetterCommand<dynamic, T>? get parent =>
      super.parent as BetterCommand<dynamic, T>?;

  @override
  BetterCommandRunner<dynamic, T>? get runner =>
      super.runner as BetterCommandRunner<dynamic, T>?;

  @override
  ArgParser get argParser => _argParser;

  @override
  void printUsage() {
    messageOutput?.logUsage(usage);
  }

  /// Runs this command.
  /// Resolves the configuration (args, env, etc) and runs the command
  /// subclass via [runWithConfig].
  ///
  /// If there are errors resolving the configuration,
  /// a UsageException is thrown with appropriate error messages.
  ///
  /// Subclasses should override [runWithConfig],
  /// unless they want to handle the configuration resolution themselves.
  @override
  FutureOr<T>? run() {
    final config = resolveConfiguration(argResults);

    if (config.errors.isNotEmpty) {
      final buffer = StringBuffer();
      final errors = config.errors.map(formatConfigError);
      buffer.writeAll(errors, '\n');
      usageException(buffer.toString());
    }

    return runWithConfig(config);
  }

  /// Resolves the configuration for this command.
  ///
  /// This method can be overridden to change the configuration resolution
  /// behavior.
  Configuration<O> resolveConfiguration(ArgResults? argResults) {
    return Configuration.resolve(
      options: options,
      argResults: argResults,
      env: envVariables,
    );
  }

  /// Runs this command with the resolved configuration (option values).
  /// Subclasses should override this method.
  FutureOr<T>? runWithConfig(final Configuration<O> commandConfig);
}
