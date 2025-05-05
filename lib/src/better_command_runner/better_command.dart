import 'dart:async' show FutureOr;

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_tools/better_command_runner.dart';
import 'package:cli_tools/config.dart';

import 'config_resolver.dart';

abstract class BetterCommand<O extends OptionDefinition, T> extends Command<T> {
  static const _defaultMessageOutput = MessageOutput(usageLogger: print);

  final MessageOutput? _messageOutput;
  final ArgParser _argParser;

  /// The configuration resolver for this command.
  ConfigResolver? _configResolver;

  /// The option definitions for this command.
  final List<O> options;

  /// Creates a new instance of [BetterCommand].
  ///
  /// - [messageOutput] is an optional [MessageOutput] object used to pass specific log messages.
  /// - [wrapTextColumn] is the column width for wrapping text in the command line interface.
  /// - [options] is a list of options, empty by default.
  /// - [configResolver] is an optional custom [ConfigResolver] implementation.
  ///
  /// [configResolver] and [messageOutput] are optional and will default to the
  /// values of the command runner (if any).
  ///
  /// If no [configResolver] is provided then [DefaultConfigResolver] will be used,
  /// which uses the command line arguments and environment variables as input sources.
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
    ConfigResolver? configResolver,
  })  : _messageOutput = messageOutput,
        _argParser = ArgParser(usageLineLength: wrapTextColumn),
        _configResolver = configResolver {
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

  ConfigResolver get configResolver {
    if (runner case BetterCommandRunner<O, T> runner) {
      return runner.configResolver;
    }
    return _configResolver ??= DefaultConfigResolver();
  }

  @override
  BetterCommand<O, T>? get parent => super.parent as BetterCommand<O, T>?;

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
  /// Subclasses should override [runWithConfig],
  /// unless they want to handle the configuration resolution themselves.
  @override
  FutureOr<T>? run() {
    final config = resolveConfiguration(argResults);

    return runWithConfig(config);
  }

  /// Resolves the configuration for this command
  /// using the preset [ConfigResolver].
  /// If there are errors resolving the configuration,
  /// a UsageException is thrown with appropriate error messages.
  ///
  /// This method can be overridden to change the configuration resolution
  /// or error handling behavior.
  Configuration<O> resolveConfiguration(ArgResults? argResults) {
    final config = configResolver.resolveConfiguration(
      options: options,
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

  /// Runs this command with prepared configuration (options).
  /// Subclasses should override this method.
  FutureOr<T>? runWithConfig(final Configuration<O> commandConfig);
}
