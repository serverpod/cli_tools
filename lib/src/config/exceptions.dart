import 'package:cli_tools/src/config/options.dart';

/// Indicates that the option definition is invalid.
class InvalidOptionConfigurationError extends Error {
  final OptionDefinition option;
  final String? message;

  InvalidOptionConfigurationError(this.option, [this.message]);

  @override
  String toString() {
    return message != null
        ? 'Invalid configuration for ${option.qualifiedString()}: $message'
        : 'Invalid configuration for ${option.qualifiedString()}';
  }
}
