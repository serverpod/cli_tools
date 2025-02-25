import 'package:cli_tools/cli_tools.dart';
import 'package:test/test.dart';

import 'test_utils/io_helper.dart';

void main() {
  group('Given a StdOutLogger with default settings', () {
    var logger = StdOutLogger(LogLevel.debug);

    test(
        'when logging debug message '
        'then log output is written to stdout and correct', () async {
      var (:stdout, :stderr, :stdin) = await collectOutput(
        () => logger.debug('debug message'),
      );
      expect(stdout.output, 'DEBUG: debug message\n');
      expect(stderr.output, '');
    });

    test(
        'when logging info message '
        'then log output is written to stdout and correct', () async {
      var (:stdout, :stderr, :stdin) = await collectOutput(
        () => logger.info('info message'),
      );
      expect(stdout.output, 'info message\n');
      expect(stderr.output, '');
    });

    test(
        'when logging warning message '
        'then log output is written to stdout and correct', () async {
      var (:stdout, :stderr, :stdin) = await collectOutput(
        () => logger.warning('warning message'),
      );
      expect(stdout.output, 'WARNING: warning message\n');
      expect(stderr.output, '');
    });

    test(
        'when logging error message '
        'then log output is written to stdout and correct', () async {
      var (:stdout, :stderr, :stdin) = await collectOutput(
        () => logger.error('error message'),
      );
      expect(stdout.output, 'ERROR: error message\n');
      expect(stderr.output, '');
    });
  });

  group('Given a StdOutLogger with warning log-to-stderr threshold', () {
    var logger = StdOutLogger(
      LogLevel.debug,
      logToStderrLevelThreshold: LogLevel.warning,
    );

    test(
        'when logging debug message '
        'then log output is written to stdout and correct', () async {
      var (:stdout, :stderr, :stdin) = await collectOutput(
        () => logger.debug('debug message'),
      );
      expect(stdout.output, 'DEBUG: debug message\n');
      expect(stderr.output, '');
    });

    test(
        'when logging info message '
        'then log output is written to stdout and correct', () async {
      var (:stdout, :stderr, :stdin) = await collectOutput(
        () => logger.info('info message'),
      );
      expect(stdout.output, 'info message\n');
      expect(stderr.output, '');
    });

    test(
        'when logging warning message '
        'then log output is written to stderr and correct', () async {
      var (:stdout, :stderr, :stdin) = await collectOutput(
        () => logger.warning('warning message'),
      );
      expect(stdout.output, '');
      expect(stderr.output, 'WARNING: warning message\n');
    });

    test(
        'when logging error message '
        'then log output is written to stderr and correct', () async {
      var (:stdout, :stderr, :stdin) = await collectOutput(
        () => logger.error('error message'),
      );
      expect(stdout.output, '');
      expect(stderr.output, 'ERROR: error message\n');
    });
  });
}
