import 'source_type.dart';

base mixin OptionResolutionData<V> {
  String? get stringValue;
  V? get value;
  String? get error;
  ValueSourceType get source;

  /// Whether there was an error during resolving this Option.
  bool get hasError => error == null;

  /// Whether the option has a proper value (without errors).
  bool get hasValue => !hasError && source != ValueSourceType.noValue;

  /// Whether the option has a value that was specified explicitly (not default).
  bool get isSpecified => hasValue && source != ValueSourceType.defaultValue;

  /// Whether the option has the default value.
  bool get isDefault => hasValue && source == ValueSourceType.defaultValue;
}
