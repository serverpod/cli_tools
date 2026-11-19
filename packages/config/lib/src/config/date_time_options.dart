import 'option_types.dart';
import 'options.dart';

/// Parses a calendar date or a date-time into a [DateTime].
///
/// Throws [FormatException] if [value] is not a valid date or date-time.
///
/// A calendar date is `YYYY-MM-DD` or the compact form `YYYYMMDD`
/// (four-digit year, optional `+` or `-` sign). A date-time adds a
/// time, separated by `T`, a space, or one of `-_/:t`. The time is
/// `HH[:MM[:SS[(.|,)fraction]]]`, then an optional `Z` or numeric offset
/// (`±HH`, `±HHMM`, or `±HH:MM`).
///
/// Components must be in range. `2026-02-31` does not roll into March,
/// and hour `24`, minute `60`, and second `60` are rejected. Fractional
/// seconds longer than 6 digits are rejected instead of being truncated.
///
/// The zone follows [DateTime.parse]: a value with no offset is local,
/// and `Z` or a numeric offset is UTC. A numeric offset is converted to
/// UTC.
///
/// When [dateOnly] is true, a time part is rejected. The result is local
/// midnight on that calendar date. A local midnight that falls on a different
/// calendar day, which can happen when a time zone skips that day, is rejected.
class DateTimeParser extends ValueParser<DateTime> {
  /// When true, only a calendar date is accepted.
  final bool dateOnly;

  const DateTimeParser({this.dateOnly = false});

  /// Date or date-time grammar, plus `-_/:t` as date/time separators.
  /// The year is exactly four digits.
  ///
  /// Groups: year, dash, month, dash, day, hour, minute, second,
  /// fraction, zone, zone sign, zone hour, zone minute.
  /// The two date dashes are both present (`YYYY-MM-DD`) or both absent
  /// (`YYYYMMDD`), so a longer year is not read as a four-digit year.
  static final RegExp _pattern = RegExp(
    r'^([+-]?\d{4})(-)?(\d\d)(-)?(\d\d)'
    r'(?:[ T_/:t-](\d\d)(?::?(\d\d)(?::?(\d\d)(?:[.,](\d+))?)?)?'
    r'( ?[zZ]| ?([-+])(\d\d)(?::?(\d\d))?)?)?$',
  );

  @override
  DateTime parse(final String value) {
    final match = _pattern.firstMatch(value);
    if (match == null) {
      throw FormatException(_invalid(value));
    }

    final year = int.parse(match[1]!);
    final month = int.parse(match[3]!);
    final day = int.parse(match[5]!);
    if ((match[2] == null) != (match[4] == null)) {
      throw FormatException(_invalid(value));
    }
    final hourText = match[6];
    if (dateOnly && hourText != null) {
      throw FormatException(_invalid(value, 'a time is not allowed'));
    }

    final hour = hourText == null ? 0 : int.parse(hourText);
    final minute = _number(match[7]);
    final second = _number(match[8]);
    final fraction = match[9];
    _validateDate(value, year, month, day);
    if (hourText != null) {
      _validateTime(value, hour, minute, second);
    }

    final hasZone = match[10] != null;
    final zoneSign = match[11];
    final zoneHour = zoneSign == null ? 0 : int.parse(match[12]!);
    final zoneMinute = zoneSign == null ? 0 : _number(match[13]);
    if (zoneSign != null) {
      _validateOffset(value, zoneHour, zoneMinute);
    }

    final fractionMicros = fraction == null
        ? 0
        : _fractionMicros(value, fraction);
    final millisecond = fractionMicros ~/ Duration.microsecondsPerMillisecond;
    final microsecond = fractionMicros.remainder(
      Duration.microsecondsPerMillisecond,
    );
    final parsed = hasZone
        ? DateTime.utc(
            year,
            month,
            day,
            hour,
            minute,
            second,
            millisecond,
            microsecond,
          )
        : DateTime(
            year,
            month,
            day,
            hour,
            minute,
            second,
            millisecond,
            microsecond,
          );
    if (dateOnly &&
        (parsed.year != year || parsed.month != month || parsed.day != day)) {
      throw FormatException(
        _invalid(
          value,
          'that calendar date does not exist in the local time zone',
        ),
      );
    }
    if (!hasZone || zoneSign == null || (zoneHour == 0 && zoneMinute == 0)) {
      return parsed;
    }

    final offset = Duration(hours: zoneHour, minutes: zoneMinute);
    return zoneSign == '-' ? parsed.add(offset) : parsed.subtract(offset);
  }

  /// Formats [value] as text that [parse] accepts.
  ///
  /// A local date-time has no zone suffix. A UTC date-time ends in `Z`.
  /// A calendar date is `YYYY-MM-DD` from [value]'s year, month, and day.
  @override
  String format(final DateTime value) {
    if (dateOnly) return _calendarDate(value);
    final zone = value.isUtc ? 'Z' : '';
    return '${_calendarDate(value)}${_timeOfDay(value)}$zone';
  }

  String _invalid(final String value, [final String? detail]) {
    final kind = dateOnly ? 'date' : 'date-time';
    if (detail == null) return 'Invalid $kind "$value"';
    return 'Invalid $kind "$value": $detail';
  }

  void _validateDate(
    final String value,
    final int year,
    final int month,
    final int day,
  ) {
    if (month < 1 || month > 12) {
      throw FormatException(_invalid(value, 'month must be between 1 and 12'));
    }
    final maxDay = _daysInMonth(year, month);
    if (day < 1 || day > maxDay) {
      throw FormatException(
        _invalid(value, 'day must be between 1 and $maxDay'),
      );
    }
  }

  void _validateTime(
    final String value,
    final int hour,
    final int minute,
    final int second,
  ) {
    if (hour < 0 || hour > 23) {
      throw FormatException(_invalid(value, 'hour must be between 0 and 23'));
    }
    if (minute < 0 || minute > 59) {
      throw FormatException(
        _invalid(value, 'minute must be between 0 and 59'),
      );
    }
    if (second < 0 || second > 59) {
      throw FormatException(
        _invalid(value, 'second must be between 0 and 59'),
      );
    }
  }

  void _validateOffset(
    final String value,
    final int hour,
    final int minute,
  ) {
    if (hour < 0 || hour > 23) {
      throw FormatException(
        _invalid(value, 'time-zone hour must be between 0 and 23'),
      );
    }
    if (minute < 0 || minute > 59) {
      throw FormatException(
        _invalid(value, 'time-zone minute must be between 0 and 59'),
      );
    }
  }

  int _fractionMicros(final String value, final String digits) {
    if (digits.length > 6) {
      throw FormatException(
        _invalid(value, 'fractional seconds must have at most 6 digits'),
      );
    }
    var result = 0;
    for (var i = 0; i < 6; i++) {
      result *= 10;
      if (i < digits.length) {
        result += digits.codeUnitAt(i) - 0x30;
      }
    }
    return result;
  }

  static int _number(final String? text) => text == null ? 0 : int.parse(text);

  static int _daysInMonth(final int year, final int month) {
    switch (month) {
      case 2:
        return _isLeapYear(year) ? 29 : 28;
      case 4:
      case 6:
      case 9:
      case 11:
        return 30;
      default:
        return 31;
    }
  }

  /// Proleptic Gregorian leap rule, including year 0 and negative years.
  static bool _isLeapYear(final int year) {
    if (year % 4 != 0) return false;
    if (year % 100 != 0) return true;
    return year % 400 == 0;
  }

  static String _calendarDate(final DateTime value) {
    final year = value.year.abs().toString().padLeft(4, '0');
    final sign = value.year < 0 ? '-' : '';
    return '$sign$year-${_two(value.month)}-${_two(value.day)}';
  }

  static String _timeOfDay(final DateTime value) {
    final fraction = value.millisecond * 1000 + value.microsecond;
    return 'T${_two(value.hour)}:${_two(value.minute)}:${_two(value.second)}'
        '${_fraction(fraction)}';
  }

  static String _fraction(final int microseconds) {
    if (microseconds == 0) return '';
    final digits = microseconds.toString().padLeft(6, '0');
    var end = digits.length;
    while (end > 0 && digits[end - 1] == '0') {
      end--;
    }
    return '.${digits.substring(0, end)}';
  }

  static String _two(final int value) => value.toString().padLeft(2, '0');
}

/// Date-time value configuration option.
///
/// Supports minimum and maximum range checking. Limits are compared as
/// instants. A parsed value with no offset is local, and one with `Z` or
/// a numeric offset is UTC.
///
/// Set [dateOnly] to accept only a calendar date. The value is local
/// midnight on that date, including a typed default or configuration value:
/// its year, month, and day are kept and the time of day is not part of the
/// value. Allowed values match on that calendar date, so a UTC date and a
/// local date on the same day are the same choice. The value help then
/// describes the date (`YYYY-MM-DD`) instead of a timestamp.
class DateTimeOption extends ComparableValueOption<DateTime> {
  /// When true, only a calendar date (`YYYY-MM-DD`) is accepted.
  final bool dateOnly;

  const DateTimeOption({
    this.dateOnly = false,
    final String? valueHelp,
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
    super.allowedHelp,
    super.group,
    super.allowedValues,
    super.customValidator,
    super.mandatory,
    super.hide,
    super.min,
    super.max,
  }) : super(
         valueParser: dateOnly
             ? const DateTimeParser(dateOnly: true)
             : const DateTimeParser(),
         valueHelp:
             valueHelp ?? (dateOnly ? 'YYYY-MM-DD' : 'YYYY-MM-DDTHH:MM:SSZ'),
       );

  /// Date-only allowed values are calendar dates. A UTC midnight and the
  /// local midnight of the same day are the same choice, which is also what
  /// completion offers.
  @override
  bool allowsValue(final DateTime value) {
    if (!dateOnly) return super.allowsValue(value);
    final allowed = allowedValues;
    if (allowed == null) return true;
    return allowed.any(
      (final candidate) =>
          candidate.year == value.year &&
          candidate.month == value.month &&
          candidate.day == value.day,
    );
  }

  /// A date-only value is local midnight on its calendar date.
  ///
  /// Throws [FormatException] when that local midnight would fall on a
  /// different day.
  @override
  DateTime canonicalize(final DateTime value) {
    if (!dateOnly) return value;
    final local = DateTime(value.year, value.month, value.day);
    if (local.year != value.year ||
        local.month != value.month ||
        local.day != value.day) {
      throw FormatException(
        '${valueParser.format(value)} does not exist in the local time zone',
      );
    }
    return local;
  }
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
    const pattern = r'^(-?\d+)(ms|us|[smhd])?$';
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
    super.configKeys,
    super.fromCustom,
    super.fromDefault,
    super.defaultsTo,
    super.defaultValueHelp,
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
    super.configKeys,
    super.fromCustom,
    super.fromDefault,
    super.defaultsTo,
    super.defaultValueHelp,
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
