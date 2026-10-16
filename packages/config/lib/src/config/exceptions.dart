import 'options.dart';

export 'package:args/command_runner.dart' show UsageException;

/// Indicates that the option definition is invalid.
class OptionDefinitionError extends Error {
  final OptionDefinition option;
  final String? message;

  OptionDefinitionError(this.option, [this.message]);

  @override
  String toString() {
    return message != null
        ? 'Invalid definition for ${option.qualifiedString()}: $message'
        : 'Invalid definition for ${option.qualifiedString()}';
  }
}

/// Specialized [StateError] that indicates that the configuration
/// has not been successfully parsed and this prevents accessing
/// some or all of the configuration values.
class InvalidParseStateError extends StateError {
  InvalidParseStateError(super.message);
}

/// Indicates that the value of an option is invalid.
/// Used by option implementations: Thrown by [ConfigOptionBase.validateValue]
/// when a value is invalid.
/// Not normally thrown to package users, it gets converted to [UsageException].
class InvalidValueException implements Exception {
  final String message;

  InvalidValueException(this.message);

  @override
  String toString() {
    return '$runtimeType: $message';
  }
}
