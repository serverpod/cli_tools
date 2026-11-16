import 'package:args/command_runner.dart' show UsageException;

import 'arg_parser/arg_parser.dart' show CommandDefinition;
import 'options.dart';

export 'package:args/command_runner.dart' show UsageException;

sealed class ConfigDefinitionError extends Error {}

/// Indicates that the option definition is invalid.
class OptionDefinitionError extends ConfigDefinitionError {
  final OptionDefinition option;
  final String? message;

  OptionDefinitionError(this.option, [this.message]);

  @override
  String toString() {
    return message != null
        ? '$runtimeType: Invalid definition for ${option.qualifiedString()}: $message'
        : '$runtimeType: Invalid definition for ${option.qualifiedString()}';
  }
}

/// Indicates that the command definition is invalid.
class CommandDefinitionError extends ConfigDefinitionError {
  final CommandDefinition command;
  final String? message;

  CommandDefinitionError(this.command, [this.message]);

  @override
  String toString() {
    final label = 'command `${command.name}`';
    return message != null
        ? '$runtimeType: Invalid definition for $label: $message'
        : '$runtimeType: Invalid definition for $label';
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

class CommandUsageException extends UsageException {
  final CommandDefinition command;

  CommandUsageException(final String message, this.command)
    : super(message, '');

  @override
  String toString() {
    return 'Usage error for command: ${command.name}\n$message';
  }
}
