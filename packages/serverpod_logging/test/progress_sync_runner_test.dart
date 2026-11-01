import 'package:serverpod_logging/serverpod_logging.dart';
import 'package:test/test.dart';

/// [Log.progress] accepts a `FutureOr<T> Function()` runner, so a plain
/// synchronous callback (`() => value`, not `() async => value`) is a
/// supported call shape. These tests pin that contract.
void main() {
  group('Given Log.progress with a synchronous runner', () {
    late TestLogWriter writer;
    late Log log;

    setUp(() {
      writer = TestLogWriter();
      log = Log(writer);
    });

    test('when the runner returns true synchronously, '
        'then the scope closes with success true', () async {
      final result = await log.progress('op', () => true);

      expect(result, isTrue);
      expect(writer.closedScopes.single.success, isTrue);
    });

    test('when the runner returns false synchronously, '
        'then the scope closes with success false', () async {
      final result = await log.progress('op', () => false);

      expect(result, isFalse);
      expect(writer.closedScopes.single.success, isFalse);
    });

    test(
      'when a synchronous runner returns a non-bool value, '
      'then the value is returned and the scope closes successfully',
      () async {
        final result = await log.progress<String>('op', () => 'ok');

        expect(result, 'ok');
        expect(writer.closedScopes.single.success, isTrue);
      },
    );

    test('when a synchronous runner emits a log entry, '
        'then that entry is scoped to the progress scope', () async {
      await log.progress('op', () {
        log.info('inside');
        return true;
      });
      await log.flush();

      final opened = writer.openedScopes.single;
      final inside = writer.entries.singleWhere((e) => e.message == 'inside');
      expect(inside.scope.id, opened.id);
    });

    test('when a synchronous runner throws, '
        'then the scope closes with success false and rethrows', () async {
      await expectLater(
        log.progress<bool>('op', () => throw StateError('boom')),
        throwsA(isA<StateError>()),
      );

      expect(writer.closedScopes.single.success, isFalse);
      expect(writer.closedScopes.single.error, isA<StateError>());
    });
  });
}
