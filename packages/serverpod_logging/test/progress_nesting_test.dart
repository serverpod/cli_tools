import 'package:serverpod_logging/serverpod_logging.dart';
import 'package:test/test.dart';

/// Regression guard for the Zone-based scoping contract of [Log.progress].
///
/// The whole point of [Log.progress] is documented as:
///   "Log calls inside the runner are automatically scoped via the Zone."
///
/// A `log.info(...)` emitted from within the runner must be attributed
/// to the progress scope, not to the enclosing/root scope. This is a pure
/// framework property and has nothing to do with how (or whether) the scope
/// is rendered.
void main() {
  group('Given Log.progress with a runner that logs', () {
    late TestLogWriter writer;
    late Log log;

    setUp(() {
      writer = TestLogWriter();
      log = Log(writer);
    });

    test('when the runner emits a log entry, '
        'then that entry is scoped to the progress scope', () async {
      await log.progress('outer', () async {
        log.info('inside');
      });
      await log.flush();

      final opened = writer.openedScopes.single;
      expect(opened.label, 'outer');

      final inside = writer.entries.singleWhere((e) => e.message == 'inside');
      expect(
        inside.scope.id,
        opened.id,
        reason:
            'a log emitted inside the runner must reference the '
            'progress scope, via the Zone',
      );
      expect(inside.scope.label, 'outer');
    });

    test('when the runner opens a nested progress scope, '
        'then the inner scope is a child of the outer scope', () async {
      await log.progress('outer', () async {
        await log.progress('inner', () async => true);
      });
      await log.flush();

      final outer = writer.openedScopes.firstWhere((s) => s.label == 'outer');
      final inner = writer.openedScopes.firstWhere((s) => s.label == 'inner');
      expect(
        inner.parent?.id,
        outer.id,
        reason:
            'the inner progress scope must nest under the outer one, '
            'which only works if the runner executes inside the outer Zone',
      );
    });
  });
}
