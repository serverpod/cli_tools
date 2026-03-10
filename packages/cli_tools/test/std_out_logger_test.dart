// ignore required for Dart 3.3
// ignore_for_file: unused_local_variable

import 'package:cli_tools/cli_tools.dart';
import 'package:test/test.dart';

import 'test_utils/io_helper.dart';

void main() {
  group('Given a StdOutLogger with default settings', () {
    final logger = StdOutLogger(LogLevel.debug);

    test(
        'when logging debug message '
        'then log output is written to stdout and correct', () async {
      final (:stdout, :stderr, :stdin) = await collectOutput(
        () => logger.debug('debug message'),
      );
      expect(stdout.output, 'DEBUG: debug message\n');
      expect(stderr.output, '');
    });

    test(
        'when logging info message '
        'then log output is written to stdout and correct', () async {
      final (:stdout, :stderr, :stdin) = await collectOutput(
        () => logger.info('info message'),
      );
      expect(stdout.output, 'info message\n');
      expect(stderr.output, '');
    });

    test(
        'when logging warning message '
        'then log output is written to stdout and correct', () async {
      final (:stdout, :stderr, :stdin) = await collectOutput(
        () => logger.warning('warning message'),
      );
      expect(stdout.output, 'WARNING: warning message\n');
      expect(stderr.output, '');
    });

    test(
        'when logging error message via log method'
        'then log output is written to stdout and correct', () async {
      final (:stdout, :stderr, :stdin) = await collectOutput(
        () => logger.log('error message', LogLevel.error),
      );
      expect(stdout.output, 'ERROR: error message\n');
      expect(stderr.output, '');
    });

    test(
        'when logging debug message via log method'
        'then log output is written to stdout and correct', () async {
      final (:stdout, :stderr, :stdin) = await collectOutput(
        () => logger.log('debug message', LogLevel.debug),
      );
      expect(stdout.output, 'DEBUG: debug message\n');
      expect(stderr.output, '');
    });

    test(
        'when logging info message via log method'
        'then log output is written to stdout and correct', () async {
      final (:stdout, :stderr, :stdin) = await collectOutput(
        () => logger.log('info message', LogLevel.info),
      );
      expect(stdout.output, 'info message\n');
      expect(stderr.output, '');
    });

    test(
        'when logging warning message via log method'
        'then log output is written to stdout and correct', () async {
      final (:stdout, :stderr, :stdin) = await collectOutput(
        () => logger.log('warning message', LogLevel.warning),
      );
      expect(stdout.output, 'WARNING: warning message\n');
      expect(stderr.output, '');
    });

    test(
        'when logging error message '
        'then log output is written to stdout and correct', () async {
      final (:stdout, :stderr, :stdin) = await collectOutput(
        () => logger.error('error message'),
      );
      expect(stdout.output, 'ERROR: error message\n');
      expect(stderr.output, '');
    });
  });

  group('Given a StdOutLogger with warning log-to-stderr threshold', () {
    final logger = StdOutLogger(
      LogLevel.debug,
      logToStderrLevelThreshold: LogLevel.warning,
    );

    test(
        'when logging debug message '
        'then log output is written to stdout and correct', () async {
      final (:stdout, :stderr, :stdin) = await collectOutput(
        () => logger.debug('debug message'),
      );
      expect(stdout.output, 'DEBUG: debug message\n');
      expect(stderr.output, '');
    });

    test(
        'when logging info message '
        'then log output is written to stdout and correct', () async {
      final (:stdout, :stderr, :stdin) = await collectOutput(
        () => logger.info('info message'),
      );
      expect(stdout.output, 'info message\n');
      expect(stderr.output, '');
    });

    test(
        'when logging warning message '
        'then log output is written to stderr and correct', () async {
      final (:stdout, :stderr, :stdin) = await collectOutput(
        () => logger.warning('warning message'),
      );
      expect(stdout.output, '');
      expect(stderr.output, 'WARNING: warning message\n');
    });

    test(
        'when logging error message '
        'then log output is written to stderr and correct', () async {
      final (:stdout, :stderr, :stdin) = await collectOutput(
        () => logger.error('error message'),
      );
      expect(stdout.output, '');
      expect(stderr.output, 'ERROR: error message\n');
    });
  });

  group('Given a StdOutLogger logging BoxLogType messages', () {
    final logger = StdOutLogger(LogLevel.debug);

    test(
        'when logging boxed plain text '
        'then it renders the expected box framing', () async {
      final (:stdout, :stderr, :stdin) = await collectOutput(
        () => logger.info('hello world', type: BoxLogType(title: 'title')),
      );

      expect(
        stdout.output,
        '┌─ title ─────┐\n'
        '│ hello world │\n'
        '└─────────────┘\n',
      );
      expect(stderr.output, '');
    });

    test(
        'when logging boxed ANSI-styled text '
        'then ANSI codes are stripped before width calculation', () async {
      final (:stdout, :stderr, :stdin) = await collectOutput(
        () => logger.warning(
          '\x1B[33mwarning\x1B[0m',
          type: BoxLogType(title: '\x1B[31mwarn\x1B[0m'),
        ),
        ansiSupported: true,
      );

      final stripped = stdout.output.replaceAll(
        RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]|\x1B\][^\x07\x1B]*(?:\x07|\x1B\\\\)|\x1B[@-Z\\\\-_]'),
        '',
      );

      expect(stdout.output.contains('\x1B['), isTrue);
      expect(
        stripped,
        '┌─ warn ──┐\n'
        '│ warning │\n'
        '└─────────┘\n',
      );
      expect(stderr.output, '');
    });

    test(
        'when logging boxed text containing non-SGR ANSI sequences '
        'then control sequences are stripped before width calculation',
        () async {
      final (:stdout, :stderr, :stdin) = await collectOutput(
        () => logger.warning(
          '\x1B]8;;https://example.com\x07click\x1B]8;;\x07',
          type: BoxLogType(title: '\x1B[2Kwarn\x1B[0G'),
        ),
        ansiSupported: true,
      );

      final stripped = stdout.output.replaceAll(
        RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]|\x1B\][^\x07\x1B]*(?:\x07|\x1B\\\\)|\x1B[@-Z\\\\-_]'),
        '',
      );

      expect(stdout.output.contains('\x1B'), isTrue);
      expect(
        stripped,
        '┌─ warn ─┐\n'
        '│ click │\n'
        '└───────┘\n',
      );
      expect(stderr.output, '');
    });
  });
}

