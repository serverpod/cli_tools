import 'dart:io' show File, Platform;

import 'package:config/config.dart';

/// Example of accessing a configuration file as fallback if the option
/// is not specified on the command line.
/// It also shows how to make the configuration file itself
/// configurable via the command line or environment variable.
///
/// Run this example program like so:
/// ```sh
/// dart run example/config_file_example.dart --config=example/config.yaml
/// ```
/// or
/// ```sh
/// CONFIG_FILE=example/config.yaml dart run example/config_file_example.dart
/// ```
/// Command line usage:
/// ```sh
///     --config                               The path to the config file
///                                            (defaults to "File: 'example/config.yaml'")
/// -i, --interval=<integer[us|ms|s|m|h|d]>    The interval between the series elements
/// ```
Future<int> main(final List<String> args) async {
  final Configuration<TimeSeriesOption> config;
  try {
    config = Configuration.resolve(
      options: TimeSeriesOption.values,
      args: args,
      env: Platform.environment,
      configBroker: FileConfigBroker(),
    );
  } on UsageException catch (e) {
    print(e);
    return 1;
  }

  final interval = config.optionalValue(TimeSeriesOption.interval);
  print('interval: $interval');
  return 0;
}

enum TimeSeriesOption<V> implements OptionDefinition<V> {
  configFile(FileOption(
    argName: 'config',
    envName: 'CONFIG_FILE',
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
