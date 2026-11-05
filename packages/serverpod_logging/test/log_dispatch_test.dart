import 'package:serverpod_logging/serverpod_logging.dart';
import 'package:test/test.dart';

/// A writer whose [log] always throws, to exercise the best-effort contract.
class _ThrowingWriter extends LogWriter {
  @override
  Future<void> log(LogEntry entry) async => throw StateError('writer boom');

  @override
  Future<void> openScope(LogScope scope) async {}

  @override
  Future<void> closeScope(
    LogScope scope, {
    required bool success,
    required Duration duration,
    Object? error,
    StackTrace? stackTrace,
  }) async {}
}

/// A writer that records the order in which entries are actually written,
/// after an artificial per-message delay.
class _DelayedOrderWriter extends LogWriter {
  _DelayedOrderWriter(this.delayFor);

  final Duration Function(String message) delayFor;
  final List<String> writeOrder = [];

  @override
  Future<void> log(LogEntry entry) async {
    await Future<void>.delayed(delayFor(entry.message));
    writeOrder.add(entry.message);
  }

  @override
  Future<void> openScope(LogScope scope) async {}

  @override
  Future<void> closeScope(
    LogScope scope, {
    required bool success,
    required Duration duration,
    Object? error,
    StackTrace? stackTrace,
  }) async {}
}

LogEntry _entry(LogLevel level, String message) => LogEntry(
  time: DateTime.now(),
  level: level,
  message: message,
  scope: LogScope.root('r'),
);

void main() {
  group('Given a Log with a warning threshold', () {
    late TestLogWriter writer;
    late Log log;

    setUp(() {
      writer = TestLogWriter();
      log = Log(writer, logLevel: LogLevel.warning);
    });

    test('when a below-threshold entry is dispatched, '
        'then it is dropped and the factory is never invoked', () async {
      var factoryInvoked = false;
      log(LogLevel.info, () {
        factoryInvoked = true;
        return _entry(LogLevel.info, 'x');
      });
      await log.flush();

      expect(
        factoryInvoked,
        isFalse,
        reason: 'gated calls must short-circuit before the factory runs',
      );
      expect(writer.entries, isEmpty);
    });

    test('when an at-threshold entry is dispatched, '
        'then it is forwarded', () async {
      log.warning('warn');
      await log.flush();

      expect(writer.entries.single.message, 'warn');
    });

    test('when the threshold is lowered at runtime, '
        'then newly-enabled levels start being forwarded', () async {
      log.info('dropped');
      log.logLevel = LogLevel.info;
      log.info('kept');
      await log.flush();

      expect(writer.entries.map((e) => e.message), ['kept']);
    });
  });

  group('Given a Log whose writer throws', () {
    test('when an entry is dispatched, '
        'then dispatch is best-effort and the error is not surfaced', () async {
      final log = Log(_ThrowingWriter());

      log.info('x');

      await expectLater(log.flush(), completes);
    });
  });

  group('Given a Log with out-of-order write timing', () {
    test('when earlier writes are slower than later ones, '
        'then writes still complete in invocation order', () async {
      final writer = _DelayedOrderWriter(
        (m) => m == '1' ? const Duration(milliseconds: 40) : Duration.zero,
      );
      final log = Log(writer);

      log.info('1');
      log.info('2');
      log.info('3');
      await log.flush();

      expect(
        writer.writeOrder,
        ['1', '2', '3'],
        reason: 'the _latest chain serializes writes in call order',
      );
    });
  });

  group('Given a closed Log', () {
    test('when an entry is dispatched after close, '
        'then it is dropped', () async {
      final writer = TestLogWriter();
      final log = Log(writer);

      log.info('before');
      await log.close();
      log.info('after');
      await log.flush();

      expect(writer.entries.map((e) => e.message), ['before']);
    });
  });

  group("Given a Log's debug gate (isDebugEnabled)", () {
    test('when the level is debug, then it is enabled', () {
      expect(
        Log(TestLogWriter(), logLevel: LogLevel.debug).isDebugEnabled,
        isTrue,
      );
    });

    test('when the level is above debug, then it is disabled', () {
      expect(
        Log(TestLogWriter(), logLevel: LogLevel.info).isDebugEnabled,
        isFalse,
      );
    });
  });

  group('Given a Log at debug level', () {
    test('when each convenience method is called, '
        'then the entry carries the matching LogLevel', () async {
      final writer = TestLogWriter();
      final log = Log(writer, logLevel: LogLevel.debug);

      log.debug('d');
      log.info('i');
      log.warning('w');
      log.error('e');
      await log.flush();

      expect(writer.entries.map((e) => e.level), [
        LogLevel.debug,
        LogLevel.info,
        LogLevel.warning,
        LogLevel.error,
      ]);
    });
  });

  group('Given the error() convenience method', () {
    test('when it is given an error and stack trace, '
        'then both are attached to the entry', () async {
      final writer = TestLogWriter();
      final log = Log(writer);
      final stackTrace = StackTrace.current;

      log.error('boom', error: StateError('x'), stackTrace: stackTrace);
      await log.flush();

      final entry = writer.entries.single;
      expect(entry.error, isA<StateError>());
      expect(entry.stackTrace, same(stackTrace));
    });
  });
}
