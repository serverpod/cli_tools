import 'dart:io' show Platform;

import 'package:args/args.dart' show ArgResults;
import 'package:cli_tools/config.dart' show Configuration, OptionDefinition;

/// {@template config_resolver}
/// Resolves a configuration for the provided options and arguments.
/// Subclasses can add additional configuration sources.
/// {@endtemplate}
///
/// The purpose of this class is to delegate the configuration resolution
/// in BetterCommandRunner and BetterCommand to a separate object
/// they can be composed with.
abstract interface class ConfigResolver<O extends OptionDefinition> {
  /// {@macro config_resolver}
  Configuration<O> resolveConfiguration({
    required Iterable<O> options,
    ArgResults? argResults,
  });
}

/// The default behavior is to invoke this using the [argResults] and
/// [Platform.environment] as input.
class DefaultConfigResolver<O extends OptionDefinition>
    implements ConfigResolver<O> {
  final Map<String, String> _env;

  DefaultConfigResolver({Map<String, String>? env})
      : _env = env ?? Platform.environment;

  @override
  Configuration<O> resolveConfiguration({
    required Iterable<O> options,
    ArgResults? argResults,
  }) {
    return Configuration.resolve(
      options: options,
      argResults: argResults,
      env: _env,
    );
  }
}

/// Formats a configuration error message.
String formatConfigError(final String error) {
  if (error.isEmpty) return error;
  final suffix = _isPunctuation(error.substring(error.length - 1)) ? '' : '.';
  return '${error[0].toUpperCase()}${error.substring(1)}$suffix';
}

/// Returns true if the character is a punctuation mark.
bool _isPunctuation(final String char) {
  return RegExp(r'\p{P}', unicode: true).hasMatch(char);
}
