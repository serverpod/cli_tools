import 'package:serverpod_logging/serverpod_logging.dart';
import 'package:test/test.dart';

void main() {
  group('Given a Log with no active progress scope', () {
    late TestLogWriter writer;
    late Log log;

    setUp(() {
      writer = TestLogWriter();
      log = Log(writer);
    });

    test('when a log is emitted, '
        'then it attaches to the synthetic root scope', () async {
      log.info('orphan');
      await log.flush();

      expect(writer.entries.single.scope.label, 'unknown');
    });

    test('when progress is given metadata, '
        'then the opened scope carries it', () async {
      await log.progress('op', () async => true, metadata: {'k': 'v'});

      expect(writer.openedScopes.single.metadata, {'k': 'v'});
    });
  });

  group('Given a root LogScope', () {
    test('when it is created, then it has no parent', () {
      expect(LogScope.root('root').parent, isNull);
    });
  });

  group('Given a child LogScope', () {
    test(
      'when it is created, '
      'then it references its parent and keeps its own id, label and metadata',
      () {
        final root = LogScope.root('root');
        final child = root.child(id: 'c1', label: 'child', metadata: {'a': 1});

        expect(child.parent, same(root));
        expect(child.id, 'c1');
        expect(child.label, 'child');
        expect(child.metadata, {'a': 1});
      },
    );
  });
}
