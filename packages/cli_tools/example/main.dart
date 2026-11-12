import 'dart:io' show exit;

import 'package:cli_tools/cli_tools.dart';
import 'package:config/command.dart'
    show Middlewares, CommandContext, CommandImpl;
import 'package:config/config.dart';

Future<void> main(final List<String> args) async {
  final commandRunner = BetterCommandRunner(
    'example',
    'Example CLI command',
    globalOptions: [
      StandardGlobalOption.quiet,
      StandardGlobalOption.verbose,
    ],
  );
  commandRunner.addCommand(TimeSeriesCommand());

  // Simple example of using the [StdOutLogger] class, and passing a global
  // logger to commands via the [ContextProvider].

  commandRunner.addMiddleware(
    Middlewares.onBeforeRun((final CommandContext context) {
      final LogLevel logLevel;
      if (context.config.value(StandardGlobalOption.verbose)) {
        logLevel = LogLevel.debug;
      } else if (context.config.value(StandardGlobalOption.quiet)) {
        logLevel = LogLevel.error;
      } else {
        logLevel = LogLevel.info;
      }
      final logger = StdOutLogger(logLevel);
      context.provider.store(logger);
    }),
  );

  commandRunner.addCommand(
    CommandImpl.leafWithRunFunction(
      name: 'log',
      description: 'Log a message',
      run: (final CommandContext context) async {
        final logger = context.provider.fetch<StdOutLogger>();
        logger.info('An info message');
        logger.error('An error message');
        logger.debug(
          'A debug message that will not be shown unless --verbose is set',
        );
        await logger.progress(
          'A progress message',
          () async => Future.delayed(const Duration(seconds: 3), () => true),
        );
      },
    ),
  );

  try {
    await commandRunner.run(args);
  } on UsageException {
    exit(1);
  }
}

/// Options are defineable as enums as well as regular lists.
///
/// The enum approach is more distinct and type safe.
/// The list approach is more dynamic and permits non-const initialization.
enum TimeSeriesOption<V extends Object> implements OptionDefinition<V> {
  until(
    DateTimeOption(
      argName: 'until',
      envName: 'SERIES_UNTIL', // can also be specified as environment variable
      fromDefault: _defaultUntil,
      helpText: 'The end timestamp of the series',
    ),
  ),
  length(
    IntOption(
      argName: 'length',
      argAbbrev: 'l',
      argPos: 0, // can also be specified as positional argument
      helpText: 'The number of elements in the series',
      min: 1,
      max: 100,
      group: _granularityGroup,
    ),
  ),
  interval(
    DurationOption(
      argName: 'interval',
      argAbbrev: 'i',
      helpText: 'The interval between the series elements',
      min: Duration(seconds: 1),
      max: Duration(days: 1),
      group: _granularityGroup,
    ),
  );

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
  void runWithConfig(final Configuration<TimeSeriesOption> commandConfig) {
    var start = DateTime.now();
    final until = commandConfig.value(TimeSeriesOption.until);

    // exactly one of these options is set
    final length = commandConfig.optionalValue(TimeSeriesOption.length);
    var interval = commandConfig.optionalValue(TimeSeriesOption.interval);
    interval ??= (until.difference(start) ~/ length!);
    if (interval < const Duration(milliseconds: 1)) {
      interval = const Duration(milliseconds: 1);
    }

    while (start.isBefore(until)) {
      print(start);
      start = start.add(interval);
    }
  }
}
