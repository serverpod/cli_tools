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
    if (mininum != null && value.compareTo(mininum) < 0) {
      throw FormatException(
        '${valueParser.format(value)} is below the minimum '
        '(${valueParser.format(mininum)})',
      );
    }
    final maximum = max;
    if (maximum != null && value.compareTo(maximum) > 0) {
      throw FormatException(
        '${valueParser.format(value)} is above the maximum '
        '(${valueParser.format(maximum)})',
      );
    }
  }
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
