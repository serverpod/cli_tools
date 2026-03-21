import 'package:args/args.dart' show ArgParser;
import 'package:cli_tools/cli_tools.dart';
import 'package:config/config.dart';

/// Simple example of using the [StdOutLogger] class.
Future<int> main(final List<String> args) async {
  final globalOptions = [
    StandardGlobalOption.quiet,
    StandardGlobalOption.verbose,
  ];
  final ArgParser argParser = ArgParser();
  prepareOptionsForParsing(globalOptions, argParser);
  final globalConfig = Configuration.resolve(
      options: globalOptions, argResults: argParser.parse(args));

  final LogLevel logLevel;
  if (globalConfig.value(StandardGlobalOption.verbose)) {
    logLevel = LogLevel.debug;
  } else if (globalConfig.value(StandardGlobalOption.quiet)) {
    logLevel = LogLevel.error;
  } else {
    logLevel = LogLevel.info;
  }
  final logger = StdOutLogger(logLevel);

  logger.info('An info message');
  logger.error('An error message');
  logger.debug(
    'A debug message that will not be shown unless --verbose is set',
  );
  await logger.progress(
    'A progress message',
    () async => Future.delayed(const Duration(seconds: 3), () => true),
  );
  return 0;
}
