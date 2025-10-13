import 'option_resolution_data.dart';
import 'source_type.dart';

final class OptionResolution<V> with OptionResolutionData<V> {
  const OptionResolution._({
    required this.source,
    this.stringValue,
    this.value,
    this.error,
  });

  const OptionResolution({
    required this.source,
    this.stringValue,
    this.value,
  }) : error = null;

  const OptionResolution.noValue()
      : source = ValueSourceType.noValue,
        stringValue = null,
        value = null,
        error = null;

  const OptionResolution.error(this.error)
      : source = ValueSourceType.noValue,
        stringValue = null,
        value = null;

  OptionResolution<V> copyWithValue(final V newValue) => OptionResolution._(
        source: source,
        stringValue: stringValue,
        value: newValue,
        error: error,
      );

  OptionResolution<V> copyWithError(final String error) => OptionResolution._(
        source: source,
        stringValue: stringValue,
        value: value,
        error: error,
      );

  @override
  final String? stringValue;

  @override
  final V? value;

  @override
  final String? error;

  @override
  final ValueSourceType source;
}
