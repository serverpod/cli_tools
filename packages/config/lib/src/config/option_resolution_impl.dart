import 'option_resolution.dart';
import 'source_type.dart';

final class OptionResolutionImpl<V> extends OptionResolution<V> {
  final String? stringValue;

  @override
  final V? value;

  @override
  final String? error;

  @override
  final ValueSourceType source;

  const OptionResolutionImpl._({
    required this.source,
    this.stringValue,
    this.value,
    this.error,
  });

  const OptionResolutionImpl({
    required this.source,
    this.stringValue,
    this.value,
  }) : error = null;

  const OptionResolutionImpl.noValue()
      : source = ValueSourceType.noValue,
        stringValue = null,
        value = null,
        error = null;

  const OptionResolutionImpl.error(this.error)
      : source = ValueSourceType.noValue,
        stringValue = null,
        value = null;

  OptionResolutionImpl<V> copyWithValue(final V newValue) =>
      OptionResolutionImpl._(
        source: source,
        stringValue: stringValue,
        value: newValue,
        error: error,
      );

  OptionResolutionImpl<V> copyWithError(final String error) =>
      OptionResolutionImpl._(
        source: source,
        stringValue: stringValue,
        value: value,
        error: error,
      );
}
