import 'source_type.dart';

/// Provides significant metadata about an Option once it is resolved.
base mixin OptionResolutionData<V> {
  /// The resolved value of this Option.
  V? get value;

  /// The source from where this Option has been resolved.
  ValueSourceType get source;

  /// A string representation of this Option's value.
  String? get stringValue;

  /// An Error that may have been encountered during Option Resolution.
  String? get error;

  /// Whether there was an error during resolving this Option.
  bool get hasError => error != null;

  /// Whether the option has a proper value (without errors).
  bool get hasValue => !hasError && source != ValueSourceType.noValue;

  /// Whether the option has a value that was specified explicitly (not default).
  bool get isSpecified => hasValue && source != ValueSourceType.defaultValue;

  /// Whether the option has the default value.
  bool get isDefault => hasValue && source == ValueSourceType.defaultValue;
}
