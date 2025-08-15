import 'package:cli_tools/better_command_runner.dart';
import 'package:config/config.dart';

/// Example of using [BetterCommandRunner] to create subcommands
/// together with the `config` package to ingest configuration
/// from the command line or environment variables.
///
/// Run this example program like so:
/// ```sh
/// dart run example/simple_command_example.dart show --interval=1s
/// ```
/// or
/// ```sh
/// INTERVAL=1s dart run example/simple_command_example.dart show
/// ```
Future<int> main(final List<String> args) async {
  final commandRunner = BetterCommandRunner<OptionDefinition<Object>, void>(
    'example',
    'Example CLI command',
  );
  commandRunner.addCommand(ShowCommand());

  try {
    await commandRunner.run(args);
  } on UsageException catch (e) {
    print(e);
    return 1;
  }
  return 0;
}

enum ShowOption<V extends Object> implements OptionDefinition<V> {
  interval(DurationOption(
    argName: 'interval',
    argAbbrev: 'i',
    envName: 'INTERVAL',
    helpText: 'The time interval',
    mandatory: true,
    min: Duration(seconds: 1),
    max: Duration(days: 1),
  ));

  const ShowOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

class ShowCommand extends BetterCommand<ShowOption, void> {
  ShowCommand() : super(options: ShowOption.values);

  @override
  String get name => 'show';

  @override
  String get description => 'Show the configured interval';

  @override
  void runWithConfig(final Configuration<ShowOption> commandConfig) {
    final interval = commandConfig.value(ShowOption.interval);
    print('interval: $interval');
  }
}
