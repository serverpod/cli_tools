import 'source_type.dart';

/// Describes the resolution of a configuration option.
abstract class OptionResolution<V> {
  const OptionResolution();

  /// The resolved value of the option, or null if there was no value
  /// or if there was an error.
  V? get value;

  /// The error message if the option was not succesfully resolved.
  String? get error;

  /// The source type of the option's value.
  ValueSourceType get source;

  /// Whether the option was not succesfully resolved.
  bool get hasError => error != null;

  /// Whether the option has a proper value (without errors).
  bool get hasValue => source != ValueSourceType.noValue && !hasError;

  /// Whether the option has a value that was specified explicitly (not default).
  bool get isSpecified => hasValue && source != ValueSourceType.defaultValue;

  /// Whether the option has the default value.
  bool get isDefault => hasValue && source == ValueSourceType.defaultValue;
}
