import 'package:config/config.dart';
import 'package:config/better_command_runner.dart';

Future<int> main(List<String> args) async {
  var commandRunner = BetterCommandRunner(
    'example',
    'Example CLI command',
  );
  commandRunner.addCommand(TimeSeriesCommand());

  try {
    await commandRunner.run(args);
  } on UsageException catch (e) {
    print(e);
    return 1;
  }
  return 0;
}

enum TimeSeriesOption<V> implements OptionDefinition<V> {
  interval(DurationOption(
    argName: 'interval',
    argAbbrev: 'i',
    helpText: 'The interval between the series elements',
    mandatory: true,
    min: Duration(seconds: 1),
    max: Duration(days: 1),
  ));

  const TimeSeriesOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

class TimeSeriesCommand extends BetterCommand<TimeSeriesOption, void> {
  TimeSeriesCommand() : super(options: TimeSeriesOption.values);

  @override
  String get name => 'series';

  @override
  String get description => 'Generate a series of time stamps';

  @override
  void runWithConfig(Configuration<TimeSeriesOption> commandConfig) {
    var interval = commandConfig.value(TimeSeriesOption.interval);
    print('interval: $interval');
  }
}
