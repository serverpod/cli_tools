import 'source_type.dart';

/// Provides significant metadata about an option once it is resolved.
base mixin OptionResolutionData<V> {
  /// The resolved value of the option.
  V? get value;

  /// The source from where the option has been resolved.
  ValueSourceType get source;

  /// The string value of the option.
  String? get stringValue;

  /// Error message, if any, apropos of option resolution.
  String? get error;

  /// Whether there was an error during resolving the option.
  bool get hasError => error != null;

  /// Whether the option has a proper value (without errors).
  bool get hasValue => !hasError && source != ValueSourceType.noValue;

  /// Whether the option has a value that was specified explicitly (not default).
  bool get isSpecified => hasValue && source != ValueSourceType.defaultValue;

  /// Whether the option has the default value.
  bool get isDefault => hasValue && source == ValueSourceType.defaultValue;
}
