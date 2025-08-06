import 'package:cli_tools/cli_tools.dart';

Future<int> main(List<String> args) async {
  /// Simple example of using the [StdOutLogger] class.
  final LogLevel logLevel;
  if (args.contains('--verbose')) {
    logLevel = LogLevel.debug;
  } else if (args.contains('--quiet')) {
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
  return 0;
}
