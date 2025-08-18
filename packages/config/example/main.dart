import 'dart:io' show Platform;

import 'package:config/config.dart';

/// Example of using the [Configuration] class to resolve command line arguments and environment variables.
///
/// Run this example program like so:
/// ```sh
/// dart run example/main.dart --until=2025-08-08 --length=10
/// ```
/// or
/// ```sh
/// SERIES_UNTIL=2025-08-08 SERIES_LENGTH=10 dart run example/main.dart
/// ```
///
/// Command line usage:
/// ```sh
///     --until=<YYYY-MM-DDtHH:MM:SSz>             The end timestamp of the series
///                                                (defaults to "2025-08-08 12:06:49.611906")
///     -l, --length=<integer>                     The number of elements in the series
///     -i, --interval=<integer[us|ms|s|m|h|d]>    The interval between the series elements
/// ```
int main(final List<String> args) {
  final Configuration<TimeSeriesOption> config;
  try {
    config = Configuration.resolve(
      options: TimeSeriesOption.values,
      args: args,
      env: Platform.environment,
    );
  } on UsageException catch (e) {
    print(e);
    return 1;
  }

  generateTimeSeries(config);
  return 0;
}

/// Options are defineable as enums as well as regular lists.
///
/// The enum approach is more distinct and type safe.
/// The list approach is more dynamic and permits non-const initialization.
enum TimeSeriesOption<V extends Object> implements OptionDefinition<V> {
  until(DateTimeOption(
    argName: 'until',
    envName: 'SERIES_UNTIL', // can also be specified as environment variable
    fromDefault: _defaultUntil,
    helpText: 'The end timestamp of the series',
  )),
  length(IntOption(
    argName: 'length',
    argAbbrev: 'l',
    argPos: 0, // can also be specified as positional argument
    helpText: 'The number of elements in the series',
    min: 1,
    max: 100,
    group: _granularityGroup,
  )),
  interval(DurationOption(
    argName: 'interval',
    argAbbrev: 'i',
    helpText: 'The interval between the series elements',
    min: Duration(seconds: 1),
    max: Duration(days: 1),
    group: _granularityGroup,
  ));

  const TimeSeriesOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

/// Exactly one of the options in this group must be set.
const _granularityGroup = MutuallyExclusive(
  'Granularity',
  mode: MutuallyExclusiveMode.mandatory,
);

/// A function can be used as a const initializer.
DateTime _defaultUntil() => DateTime.now().add(const Duration(days: 1));

void generateTimeSeries(final Configuration<TimeSeriesOption> config) {
  var start = DateTime.now();
  final until = config.value(TimeSeriesOption.until);

  // exactly one of these options is set
  final length = config.optionalValue(TimeSeriesOption.length);
  var interval = config.optionalValue(TimeSeriesOption.interval);
  interval ??= (until.difference(start) ~/ length!);
  if (interval < const Duration(milliseconds: 1)) {
    interval = const Duration(milliseconds: 1);
  }

  while (start.isBefore(until)) {
    print(start);
    start = start.add(interval);
  }
}
