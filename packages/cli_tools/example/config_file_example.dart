import 'dart:io' show File;

import 'package:args/args.dart' show ArgResults;
import 'package:cli_tools/cli_tools.dart';

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
  configFile(FileOption(
    argName: 'config',
    helpText: 'The path to the config file',
    fromDefault: _defaultConfigFilePath,
    mode: PathExistMode.mustExist,
  )),
  interval(DurationOption(
    argName: 'interval',
    argAbbrev: 'i',
    configKey: '/interval', // JSON pointer
    helpText: 'The interval between the series elements',
    min: Duration(seconds: 1),
    max: Duration(days: 1),
  ));

  const TimeSeriesOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

File _defaultConfigFilePath() => File('example/config.yaml');

class TimeSeriesCommand extends BetterCommand<TimeSeriesOption, void> {
  TimeSeriesCommand({super.env}) : super(options: TimeSeriesOption.values);

  @override
  String get name => 'series';

  @override
  String get description => 'Generate a series of time stamps';

  @override
  void runWithConfig(Configuration<TimeSeriesOption> commandConfig) {
    var interval = commandConfig.optionalValue(TimeSeriesOption.interval);
    print('interval: $interval');
  }

  @override
  Configuration<TimeSeriesOption> resolveConfiguration(ArgResults? argResults) {
    return Configuration.resolveNoExcept(
      options: options,
      argResults: argResults,
      env: envVariables,
      configBroker: FileConfigBroker(),
    );
  }
}

class FileConfigBroker implements ConfigurationBroker {
  ConfigurationSource? _configSource;

  FileConfigBroker();

  @override
  String? valueOrNull(final String key, final Configuration cfg) {
    // By lazy-loading the config, the file path can depend on another option
    _configSource ??= ConfigurationParser.fromFile(
      cfg.value(TimeSeriesOption.configFile).path,
    );

    final value = _configSource?.valueOrNull(key);
    return value is String ? value : null;
  }
}
