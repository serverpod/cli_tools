import 'dart:async' show FutureOr;
import 'dart:io' show exit;

import 'package:args/command_runner.dart';
import 'package:cli_tools/cli_tools.dart';
import 'package:cli_tools/config.dart';

void main(List<String> args) async {
  var commandRunner = BetterCommandRunner(
    'example',
    'Example CLI commmand',
    globalOptions: [
      StandardGlobalOption.quiet,
      StandardGlobalOption.verbose,
    ],
  );
  commandRunner.addCommand(TimeSeriesCommand());

  try {
    await commandRunner.run(args);
  } on UsageException catch (e) {
    print(e);
    exit(1);
  }

  /// Simple example of using the [StdOutLogger] class.
  final LogLevel logLevel;
  if (commandRunner.globalConfiguration.value(StandardGlobalOption.verbose)) {
    logLevel = LogLevel.debug;
  } else if (commandRunner.globalConfiguration
      .value(StandardGlobalOption.quiet)) {
    logLevel = LogLevel.error;
  } else {
    logLevel = LogLevel.info;
  }
  var logger = StdOutLogger(logLevel);

  logger.info('An info message');
  logger.error('An error message');
  logger.debug(
    'A debug message that will not be shown unless --verbose is set',
  );
  await logger.progress(
    'A progress message',
    () async => Future.delayed(const Duration(seconds: 3), () => true),
  );
}

/// Options are defineable as enums as well as regular lists.
///
/// The enum approach is more distinct and type safe.
/// The list approach is more dynamic and permits non-const initialization.
enum TimeSeriesOption<V> implements OptionDefinition<V> {
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

class TimeSeriesCommand extends BetterCommand<TimeSeriesOption, void> {
  TimeSeriesCommand() : super(options: TimeSeriesOption.values);

  @override
  String get name => 'series';

  @override
  String get description => 'Generate a series of time stamps';

  @override
  FutureOr<void>? runWithConfig(Configuration<TimeSeriesOption> commandConfig) {
    var start = DateTime.now();
    var until = commandConfig.value(TimeSeriesOption.until);

    // exactly one of these options is set
    var length = commandConfig.optionalValue(TimeSeriesOption.length);
    var interval = commandConfig.optionalValue(TimeSeriesOption.interval);
    interval ??= (until.difference(start) ~/ length!);

    while (start.isBefore(until)) {
      print(start);
      start = start.add(interval);
    }
  }
}
