import 'package:serverpod_logging/serverpod_logging.dart';
import 'package:test/test.dart';

LogEntry _entry(String message) => LogEntry(
  time: DateTime.now(),
  level: LogLevel.info,
  message: message,
  scope: LogScope.root('r'),
);

/// A writer whose [log] is slow, so a write is reliably in-flight when the
/// isolate is asked to close.
class SlowWriter extends LogWriter {
  @override
  Future<void> log(LogEntry entry) async =>
      Future<void>.delayed(const Duration(milliseconds: 100));

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

/// A writer whose [log] fails after a delay, so a rejecting write is reliably
/// in-flight when the isolate is asked to close.
class SlowFailingWriter extends LogWriter {
  @override
  Future<void> log(LogEntry entry) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    throw StateError('write failed');
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

void main() {
  group('Given an IsolatedLogWriter wrapping a TestLogWriter', () {
    test(
      'when an entry is logged, '
      'then it is forwarded to the writer running in the isolate',
      () async {
        final writer = IsolatedLogWriter(() => TestLogWriter());

        await writer.log(_entry('hi'));

        // Read the isolate-local writer's state back across the boundary.
        final messages = await writer.evaluate(
          (w) => (w as TestLogWriter).entries.map((e) => e.message).toList(),
        );
        expect(messages, ['hi']);

        await writer.close();
      },
    );

    test(
      'when a scope is opened and closed, '
      'then both are forwarded to the writer running in the isolate',
      () async {
        final writer = IsolatedLogWriter(() => TestLogWriter());
        final scope = LogScope.root('op');

        await writer.openScope(scope);
        await writer.closeScope(scope, success: true, duration: Duration.zero);

        final opened = await writer.evaluate(
          (w) => (w as TestLogWriter).openedScopes.length,
        );
        final closed = await writer.evaluate(
          (w) => (w as TestLogWriter).closedScopes.length,
        );
        expect(opened, 1);
        expect(closed, 1);

        await writer.close();
      },
    );
  });

  group('Given an IsolatedLogWriter lifecycle', () {
    test(
      'when closed with a write in flight, '
      'then the in-flight write is swallowed and its log future completes',
      () async {
        final writer = IsolatedLogWriter(() => SlowWriter());

        final pending = writer.log(_entry('slow')); // intentionally not awaited
        await writer.close();

        await expectLater(pending, completes);
      },
    );

    test(
      'when a wrapped write fails while in flight, '
      'then close() still completes (does not rethrow the failure)',
      () async {
        final writer = IsolatedLogWriter(() => SlowFailingWriter());

        // ignore: unawaited_futures - fire-and-forget, like Log.call.
        writer.log(_entry('boom')).catchError((_) {});
        await expectLater(writer.close(), completes);
      },
    );

    test('when log is called after close, then it is a no-op', () async {
      final writer = IsolatedLogWriter(() => TestLogWriter());
      await writer.close();

      await expectLater(writer.log(_entry('x')), completes);
    });
  });
}
