import 'package:meta/meta.dart';

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
class StringOption extends ConfigOptionBase<String> {
  const StringOption({
    super.argName,
    super.argAliases,
    super.argAbbrev,
    super.argPos,
    super.envName,
    super.configKey,
    super.fromCustom,
    super.fromDefault,
    super.defaultsTo,
    super.helpText,
    super.valueHelp,
    super.allowedHelp,
    super.group,
    super.allowedValues,
    super.customValidator,
    super.mandatory,
    super.hide,
  }) : super(
          valueParser: const StringParser(),
        );
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
    super.fromCustom,
    super.fromDefault,
    super.defaultsTo,
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
    super.fromCustom,
    super.fromDefault,
    super.defaultsTo,
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
    super.fromCustom,
    super.fromDefault,
    super.defaultsTo,
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
    super.fromCustom,
    super.fromDefault,
    super.defaultsTo,
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
    super.fromCustom,
    super.fromDefault,
    super.defaultsTo,
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

/// Parses a date string into a [DateTime] object.
/// Throws [FormatException] if parsing failed.
///
/// This implementation is more forgiving than [DateTime.parse].
/// In addition to the standard T and space separators between
/// date and time it also allows [-_/:t].
class DateTimeParser extends ValueParser<DateTime> {
  const DateTimeParser();

  @override
  DateTime parse(final String value) {
    final val = DateTime.tryParse(value);
    if (val != null) return val;
    if (value.length >= 11 && '-_/:t'.contains(value[10])) {
      final val =
          DateTime.tryParse('${value.substring(0, 10)}T${value.substring(11)}');
      if (val != null) return val;
    }
    throw FormatException('Invalid date-time "$value"');
  }
}

/// Date-time value configuration option.
///
/// Supports minimum and maximum range checking.
class DateTimeOption extends ComparableValueOption<DateTime> {
  const DateTimeOption({
    super.argName,
    super.argAliases,
    super.argAbbrev,
    super.argPos,
    super.envName,
    super.configKey,
    super.fromCustom,
    super.fromDefault,
    super.defaultsTo,
    super.helpText,
    super.valueHelp = 'YYYY-MM-DDtHH:MM:SSz',
    super.allowedHelp,
    super.group,
    super.allowedValues,
    super.customValidator,
    super.mandatory,
    super.hide,
    super.min,
    super.max,
  }) : super(valueParser: const DateTimeParser());
}

/// The time units supported by the [DurationParser].
enum DurationUnit {
  microseconds('us'),
  milliseconds('ms'),
  seconds('s'),
  minutes('m'),
  hours('h'),
  days('d');

  final String suffix;

  const DurationUnit(this.suffix);
}

/// Parses a duration string into a [Duration] object.
///
/// The input string must be a number followed by an optional unit
/// which is one of: seconds (s), minutes (m), hours (h), days (d),
/// milliseconds (ms), or microseconds (us).
/// If no unit is specified, the [defaultUnit] is assumed, which is in
/// seconds if not specified otherwise.
/// Examples:
/// - `10`, equivalent to `10s`
/// - `10m`
/// - `10h`
/// - `10d`
/// - `10ms`
/// - `10us`
///
/// Throws [FormatException] if parsing failed.
class DurationParser extends ValueParser<Duration> {
  final DurationUnit defaultUnit;

  const DurationParser({this.defaultUnit = DurationUnit.seconds});

  @override
  Duration parse(final String value) {
    // integer followed by an optional unit (s, m, h, d, ms, us)
    const pattern = r'^(-?\d+)([smhd]|ms|us)?$';
    final regex = RegExp(pattern);
    final match = regex.firstMatch(value);

    if (match == null || match.groupCount != 2) {
      throw FormatException('Invalid duration value "$value"');
    }
    final valueStr = match.group(1);
    final unit = _determineUnit(match.group(2));
    final val = int.parse(valueStr ?? '');
    return switch (unit) {
      DurationUnit.seconds => Duration(seconds: val),
      DurationUnit.minutes => Duration(minutes: val),
      DurationUnit.hours => Duration(hours: val),
      DurationUnit.days => Duration(days: val),
      DurationUnit.milliseconds => Duration(milliseconds: val),
      DurationUnit.microseconds => Duration(microseconds: val),
    };
  }

  DurationUnit _determineUnit(final String? suffix) {
    if (suffix == null) return defaultUnit;

    return DurationUnit.values.firstWhere(
      (final unit) => unit.suffix == suffix,
      orElse: () => throw FormatException('Invalid duration unit "$suffix".'),
    );
  }

  @override
  String format(final Duration value) {
    if (value == Duration.zero) return '0s';

    final sign = value.isNegative ? '-' : '';
    final d = _unitStr(value.inDays, null, 'd');
    final h = _unitStr(value.inHours, 24, 'h');
    final m = _unitStr(value.inMinutes, 60, 'm');
    final s = _unitStr(value.inSeconds, 60, 's');
    final ms = _unitStr(value.inMilliseconds, 1000, 'ms');
    final us = _unitStr(value.inMicroseconds, 1000, 'us');

    return '$sign$d$h$m$s$ms$us';
  }

  static String _unitStr(final int value, final int? mod, final String unit) {
    final absValue = value.abs();
    if (mod == null) {
      return absValue > 0 ? '$absValue$unit' : '';
    }
    return absValue % mod > 0 ? '${absValue.remainder(mod)}$unit' : '';
  }
}

/// Duration value configuration option.
///
/// Supports minimum and maximum range checking.
class DurationOption extends ComparableValueOption<Duration> {
  const DurationOption({
    super.argName,
    super.argAliases,
    super.argAbbrev,
    super.argPos,
    super.envName,
    super.configKey,
    super.fromCustom,
    super.fromDefault,
    super.defaultsTo,
    super.helpText,
    super.valueHelp = 'integer[us|ms|s|m|h|d]',
    super.allowedHelp,
    super.group,
    super.allowedValues,
    super.customValidator,
    super.mandatory,
    super.hide,
    super.min,
    super.max,
  }) : super(valueParser: const DurationParser());

  /// Creates a DurationOption with a custom duration parser,
  /// e.g. with a specific default unit.
  const DurationOption.custom({
    required final DurationParser parser,
    super.argName,
    super.argAliases,
    super.argAbbrev,
    super.argPos,
    super.envName,
    super.configKey,
    super.fromCustom,
    super.fromDefault,
    super.defaultsTo,
    super.helpText,
    super.valueHelp = 'integer[us|ms|s|m|h|d]',
    super.allowedHelp,
    super.group,
    super.allowedValues,
    super.customValidator,
    super.mandatory,
    super.hide,
    super.min,
    super.max,
  }) : super(valueParser: parser);
}
