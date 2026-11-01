import 'package:serverpod_logging/serverpod_logging.dart';
import 'package:test/test.dart';

LogEntry _entry(String message) => LogEntry(
  time: DateTime.now(),
  level: LogLevel.info,
  message: message,
  scope: LogScope.root('r'),
);

/// Minimal writer that only records whether [close] was called, so the
/// close fan-out can be observed (the base [LogWriter.close] is a no-op).
class _CloseTrackingWriter extends LogWriter {
  bool closed = false;

  @override
  Future<void> log(LogEntry entry) async {}

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

  @override
  Future<void> close() async => closed = true;
}

void main() {
  group('Given a MultiLogWriter', () {
    test('when constructed with writers, '
        'then log/openScope/closeScope fan out to all of them', () async {
      final a = TestLogWriter();
      final b = TestLogWriter();
      final multi = MultiLogWriter([a, b]);
      final scope = LogScope.root('s');

      await multi.openScope(scope);
      await multi.log(_entry('hi'));
      await multi.closeScope(scope, success: true, duration: Duration.zero);

      for (final w in [a, b]) {
        expect(w.openedScopes, hasLength(1));
        expect(w.entries.single.message, 'hi');
        expect(w.closedScopes.single.success, isTrue);
      }
    });

    test('when a writer is added after construction, '
        'then it receives subsequent entries', () async {
      final added = TestLogWriter();
      final multi = MultiLogWriter([]);

      multi.add(added);
      await multi.log(_entry('after-add'));

      expect(
        added.entries.single.message,
        'after-add',
        reason: 'add() must actually wire the writer into the chain',
      );
    });

    test(
      'when a writer is removed, '
      'then it stops receiving entries and remove reports its presence',
      () async {
        final w = TestLogWriter();
        final multi = MultiLogWriter([w]);

        expect(multi.remove(w), isTrue);
        await multi.log(_entry('after-remove'));
        expect(w.entries, isEmpty);

        expect(multi.remove(w), isFalse, reason: 'already removed');
      },
    );

    test('when closed, then close fans out to all writers', () async {
      final a = _CloseTrackingWriter();
      final b = _CloseTrackingWriter();

      await MultiLogWriter([a, b]).close();

      expect(a.closed, isTrue);
      expect(b.closed, isTrue);
    });
  });
}
