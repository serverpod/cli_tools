import 'option_resolution.dart';
import 'source_type.dart';

final class OptionResolutionImpl<V> extends OptionResolution<V> {
  /// Raw source string parsed into [value].
  ///
  /// Null when the source provided [multiStringValues] or a typed [value].
  final String? stringValue;

  /// Raw source strings parsed one occurrence at a time.
  ///
  /// Null when the source provided a single [stringValue] or a typed [value].
  /// Occurrences are kept separate because a joined string cannot be split
  /// back when the separator is null or is not a [String].
  final List<String>? multiStringValues;

  @override
  final V? value;

  @override
  final String? error;

  @override
  final ValueSourceType source;

  const OptionResolutionImpl._({
    required this.source,
    this.stringValue,
    this.multiStringValues,
    this.value,
    this.error,
  });

  const OptionResolutionImpl({
    required this.source,
    this.stringValue,
    this.multiStringValues,
    this.value,
  }) : error = null;

  const OptionResolutionImpl.noValue()
    : source = ValueSourceType.noValue,
      stringValue = null,
      multiStringValues = null,
      value = null,
      error = null;

  const OptionResolutionImpl.error(this.error)
    : source = ValueSourceType.noValue,
      stringValue = null,
      multiStringValues = null,
      value = null;

  OptionResolutionImpl<V> copyWithValue(final V newValue) =>
      OptionResolutionImpl._(
        source: source,
        stringValue: stringValue,
        multiStringValues: multiStringValues,
        value: newValue,
        error: error,
      );

  OptionResolutionImpl<V> copyWithError(final String error) =>
      OptionResolutionImpl._(
        source: source,
        stringValue: stringValue,
        multiStringValues: multiStringValues,
        value: value,
        error: error,
      );
}
