import 'dart:async' show FutureOr;

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_tools/better_command_runner.dart';
import 'package:cli_tools/config.dart';

import 'config_resolver.dart';

abstract class BetterCommand<O extends OptionDefinition, T> extends Command<T> {
  final MessageOutput? _messageOutput;
  final ArgParser _argParser;

  /// The configuration resolver for this command.
  final ConfigResolver<O> _configResolver;

  /// The option definitions for this command.
  final List<O> options;

  BetterCommand({
    MessageOutput? messageOutput,
    int? wrapTextColumn,
    this.options = const [],
    final ConfigResolver<O>? configResolver,
  })  : _messageOutput = messageOutput,
        _argParser = ArgParser(usageLineLength: wrapTextColumn),
        _configResolver = configResolver ?? DefaultConfigResolver<O>() {
    prepareOptionsForParsing(options, argParser);
  }

  @override
  ArgParser get argParser => _argParser;

  @override
  void printUsage() {
    _messageOutput?.logUsage(usage);
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
    final config = _configResolver.resolveConfiguration(
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
