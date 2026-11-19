import 'dart:async' show FutureOr;

import 'package:meta/meta.dart';

import 'completion.dart';
import 'options.dart';

/// ValueParser that returns the input string unchanged.
class StringParser extends ValueParser<String> {
  const StringParser();

  @override
  String parse(final String value) {
    return value;
  }
}

/// String value configuration option.
///
/// If [requireNonEmpty] is true and the input is an empty string,
/// the validation throws a [FormatException].
class StringOption extends ConfigOptionBase<String> {
  /// When true, an empty string is rejected as an invalid value.
  final bool requireNonEmpty;

  const StringOption({
    super.argName,
    super.argAliases,
    super.argAbbrev,
    super.argPos,
    super.envName,
    super.configKey,
    super.configKeys,
    super.fromCustom,
    super.fromDefault,
    super.defaultsTo,
    super.defaultValueHelp,
    super.helpText,
    super.valueHelp,
    super.allowedHelp,
    super.group,
    super.allowedValues,
    super.customValidator,
    super.mandatory,
    super.hide,
    this.requireNonEmpty = false,
  }) : super(
         valueParser: const StringParser(),
       );

  @override
  @mustCallSuper
  void validateValue(final String value) {
    super.validateValue(value);

    if (requireNonEmpty && value.isEmpty) {
      throw const FormatException('Value must not be empty');
    }
  }
}

/// Convenience class for multi-value configuration option for strings.
class MultiStringOption extends MultiOption<String> {
  /// Creates a MultiStringOption which splits input strings on commas.
  const MultiStringOption({
    super.argName,
    super.argAliases,
    super.argAbbrev,
    super.envName,
    super.configKey,
    super.configKeys,
    super.fromCustom,
    super.fromDefault,
    super.defaultsTo,
    super.defaultValueHelp,
    super.helpText,
    super.valueHelp,
    super.allowedHelp,
    super.group,
    super.allowedValues,
    super.customValidator,
    super.mandatory,
    super.hide,
  }) : super(
         multiParser: const MultiParser(StringParser()),
       );

  /// Creates a MultiStringOption which treats input strings as single elements.
  const MultiStringOption.noSplit({
    super.argName,
    super.argAliases,
    super.argAbbrev,
    super.envName,
    super.configKey,
    super.configKeys,
    super.fromCustom,
    super.fromDefault,
    super.defaultsTo,
    super.defaultValueHelp,
    super.helpText,
    super.valueHelp,
    super.allowedHelp,
    super.group,
    super.allowedValues,
    super.customValidator,
    super.mandatory,
    super.hide,
  }) : super(
         multiParser: const MultiParser(StringParser(), separator: null),
       );
}

/// Parses a string value into an enum value.
/// Currently requires an exact, case-sensitive match.
class EnumParser<E extends Enum> extends ValueParser<E> {
  final List<E> enumValues;

  const EnumParser(this.enumValues);

  @override
  E parse(final String value) {
    return enumValues.firstWhere(
      (final e) => e.name == value,
      orElse: () => throw FormatException(
        '"$value" is not in ${valueHelpString()}',
      ),
    );
  }

  @override
  String format(final E value) {
    return value.name;
  }

  String valueHelpString() {
    return enumValues.map((final e) => e.name).join('|');
  }
}

/// Enum value configuration option.
///
/// If the input is not one of the enum names,
/// the validation throws a [FormatException].
///
/// Due to Dart's const semantics, the EnumParser must be
/// provided by the caller, like so:
///
/// ```dart
/// EnumOption(
///   enumParser: EnumParser(AnimalEnum.values),
///   argName: 'animal',
/// )
/// ```
class EnumOption<E extends Enum> extends ConfigOptionBase<E> {
  const EnumOption({
    required final EnumParser<E> enumParser,
    super.argName,
    super.argAliases,
    super.argAbbrev,
    super.argPos,
    super.envName,
    super.configKey,
    super.configKeys,
    super.fromCustom,
    super.fromDefault,
    super.defaultsTo,
    super.defaultValueHelp,
    super.helpText,
    super.valueHelp,
    super.allowedHelp,
    super.group,
    super.allowedValues,
    super.customValidator,
    super.mandatory,
    super.hide,
  }) : super(valueParser: enumParser);

  @override
  String? valueHelpString() {
    if (valueHelp != null) return valueHelp;
    if (allowedValues != null || allowedHelp != null) return null;
    // if no other value help is provided, auto-generate it with the enum names
    return (valueParser as EnumParser<E>).valueHelpString();
  }

  /// Offers the enum names, restricted to [allowedValues] when set,
  /// with descriptions from [allowedHelp].
  @override
  FutureOr<CompletionResult> complete(final CompletionContext context) {
    final values = allowedValues ?? (valueParser as EnumParser<E>).enumValues;
    return CompletionResult.values(candidatesForValues(values));
  }
}

/// Base class for configuration options that
/// support minimum and maximum range checking.
///
/// If the input is outside the specified limits
/// the validation throws a [FormatException].
class ComparableValueOption<V extends Comparable> extends ConfigOptionBase<V> {
  final V? min;
  final V? max;

  const ComparableValueOption({
    required super.valueParser,
    super.argName,
    super.argAliases,
    super.argAbbrev,
    super.argPos,
    super.envName,
    super.configKey,
    super.configKeys,
    super.fromCustom,
    super.fromDefault,
    super.defaultsTo,
    super.defaultValueHelp,
    super.helpText,
    super.valueHelp,
    super.allowedHelp,
    super.group,
    super.allowedValues,
    super.customValidator,
    super.mandatory,
    super.hide,
    this.min,
    this.max,
  });

  @override
  @mustCallSuper
  void validateValue(final V value) {
    super.validateValue(value);

    final mininum = min;
    if (mininum != null && valueIsBelow(value, mininum)) {
      throw FormatException(
        '${valueParser.format(value)} is below the minimum '
        '(${valueParser.format(mininum)})',
      );
    }
    final maximum = max;
    if (maximum != null && valueIsAbove(value, maximum)) {
      throw FormatException(
        '${valueParser.format(value)} is above the maximum '
        '(${valueParser.format(maximum)})',
      );
    }
  }

  /// Whether [value] is ordered before [limit].
  ///
  /// [DoubleOption] uses numeric comparison so that `-0.0` and `0.0`,
  /// which compare equal, are both inside a bound of zero.
  @protected
  bool valueIsBelow(final V value, final V limit) => value.compareTo(limit) < 0;

  /// Whether [value] is ordered after [limit].
  @protected
  bool valueIsAbove(final V value, final V limit) => value.compareTo(limit) > 0;
}

class IntParser extends ValueParser<int> {
  const IntParser();

  @override
  int parse(final String value) {
    return int.parse(value);
  }
}

/// Integer value configuration option.
///
/// Supports minimum and maximum range checking.
class IntOption extends ComparableValueOption<int> {
  const IntOption({
    super.argName,
    super.argAliases,
    super.argAbbrev,
    super.argPos,
    super.envName,
    super.configKey,
    super.configKeys,
    super.fromCustom,
    super.fromDefault,
    super.defaultsTo,
    super.defaultValueHelp,
    super.helpText,
    super.valueHelp = 'integer',
    super.allowedHelp,
    super.group,
    super.allowedValues,
    super.customValidator,
    super.mandatory,
    super.hide,
    super.min,
    super.max,
  }) : super(valueParser: const IntParser());
}

class DoubleParser extends ValueParser<double> {
  const DoubleParser();

  @override
  double parse(final String value) {
    return double.parse(value);
  }
}

/// Floating-point value configuration option.
///
/// Supports minimum and maximum range checking.
/// An integer string such as `1` is parsed as `1.0`. A whole number stored
/// as an integer by a configuration file is the same value.
///
/// `NaN` is rejected when [min] or [max] is set, because it is not ordered
/// relative to a bound. `-0.0` is inside a bound of `0.0`.
class DoubleOption extends ComparableValueOption<double> {
  const DoubleOption({
    super.argName,
    super.argAliases,
    super.argAbbrev,
    super.argPos,
    super.envName,
    super.configKey,
    super.configKeys,
    super.fromCustom,
    super.fromDefault,
    super.defaultsTo,
    super.defaultValueHelp,
    super.helpText,
    super.valueHelp = 'number',
    super.allowedHelp,
    super.group,
    super.allowedValues,
    super.customValidator,
    super.mandatory,
    super.hide,
    super.min,
    super.max,
  }) : super(valueParser: const DoubleParser());

  /// JSON and YAML store whole numbers as integers.
  @override
  double? valueFromConfig(final Object value) {
    if (value is int) return value.toDouble();
    return super.valueFromConfig(value);
  }

  @override
  void validateValue(final double value) {
    if (value.isNaN && (min != null || max != null)) {
      throw FormatException(
        '${valueParser.format(value)} is not a valid number',
      );
    }
    super.validateValue(value);
  }

  @override
  bool valueIsBelow(final double value, final double limit) => value < limit;

  @override
  bool valueIsAbove(final double value, final double limit) => value > limit;
}
