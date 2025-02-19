import 'package:cli_tools/cli_tools.dart';

void main() async {
  /// Simple example of using the [StdOutLogger] class.
  var logger = StdOutLogger(LogLevel.info);

  logger.info('An info message');
  logger.error('An error message');
  logger.debug(
    'A debug message that will not be shown because log level is info',
  );
  await logger.progress(
    'A progress message',
    () async => Future.delayed(const Duration(seconds: 3), () => true),
  );
}
