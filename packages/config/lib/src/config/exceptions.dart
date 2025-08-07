import 'options.dart';

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
