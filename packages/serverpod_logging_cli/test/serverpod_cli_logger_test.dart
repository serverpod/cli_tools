import 'package:cli_tools/cli_tools.dart' as cli;
import 'package:serverpod_logging/serverpod_logging.dart';
import 'package:serverpod_logging_cli/serverpod_logging_cli.dart';
import 'package:test/test.dart';

Stream<String> _failingStream(List<String> before, Object error) async* {
  for (final e in before) {
    yield e;
  }
  throw error;
}

void main() {
  group('Given a ServerpodCliLogger over a TestLogWriter', () {
    late TestLogWriter writer;
    late ServerpodCliLogger logger;

    setUp(() {
      writer = TestLogWriter();
      logger = ServerpodCliLogger(writer);
    });

    test(
      'when progress runs a runner that returns true, '
      'then it opens and closes exactly one scope marked successful',
      () async {
        final result = await logger.progress('op', () async => true);

        expect(result, isTrue);
        expect(writer.openedScopes.map((s) => s.label), ['op']);
        expect(writer.closedScopes.single.success, isTrue);
      },
    );

    test('when progress runs a runner that returns false, '
        'then the scope closes unsuccessfully', () async {
      final result = await logger.progress('op', () async => false);

      expect(result, isFalse);
      expect(writer.closedScopes.single.success, isFalse);
    });

    test(
      'when progressStream consumes a multi-event stream, '
      'then each event is a sub-operation nested under the parent '
      '(the "db shape": one parent span, one child span per event)',
      () async {
        final result = await logger.progressStream(
          'Deploying',
          Stream.fromIterable(['build', 'deploy']),
          toMessage: (s) => s,
        );

        expect(result, 'deploy');

        // Parent opens first, then a child per event.
        expect(writer.openedScopes.map((s) => s.label), [
          'Deploying',
          'build',
          'deploy',
        ]);

        final parent = writer.openedScopes.first;
        final children = writer.openedScopes.skip(1);
        expect(
          children.map((s) => s.parent?.id),
          everyElement(parent.id),
          reason: 'every event scope must nest under the parent operation',
        );

        // Children close before the parent; nothing is relabeled.
        expect(writer.closedScopes.map((c) => c.scope.label), [
          'build',
          'deploy',
          'Deploying',
        ]);
        expect(writer.closedScopes.map((c) => c.success), everyElement(isTrue));
      },
    );

    test(
      'when progressStream consumes a single event, '
      'then it behaves like one sub-operation and returns the event',
      () async {
        final result = await logger.progressStream('P', Stream.value(42));

        expect(result, 42);
        expect(writer.openedScopes.map((s) => s.label), ['P', '42']);
        expect(writer.closedScopes.map((c) => c.scope.label), ['42', 'P']);
      },
    );

    test(
      'when progressStream is given an isSuccess, '
      'then it decides the parent verdict while sub-operations stay successful',
      () async {
        await logger.progressStream(
          'P',
          Stream.fromIterable(['a', 'b']),
          toMessage: (s) => s,
          isSuccess: (s) => s == 'never',
        );

        final byLabel = {
          for (final c in writer.closedScopes) c.scope.label: c.success,
        };
        expect(byLabel['a'], isTrue);
        expect(byLabel['b'], isTrue);
        expect(byLabel['P'], isFalse, reason: 'isSuccess(last) == false');
      },
    );

    test(
      'when progressStream consumes a bool stream ending in false without '
      'isSuccess, then it still succeeds (the last event is not coerced)',
      () async {
        final result = await logger.progressStream(
          'P',
          Stream.fromIterable([true, false]),
        );

        expect(result, isFalse, reason: 'returns the last event');
        final parent = writer.closedScopes.firstWhere(
          (c) => c.scope.label == 'P',
        );
        expect(
          parent.success,
          isTrue,
          reason: 'stream completed without error -> success',
        );
      },
    );

    test(
      'when the stream errors, '
      'then the open sub-operation and the parent fail and it is rethrown',
      () async {
        await expectLater(
          logger.progressStream(
            'P',
            _failingStream(['a'], Exception('boom')),
            toMessage: (s) => s,
          ),
          throwsA(isA<Exception>()),
        );

        final byLabel = {for (final c in writer.closedScopes) c.scope.label: c};
        expect(byLabel['a']!.success, isFalse);
        expect(byLabel['a']!.error, isA<Exception>());
        expect(byLabel['P']!.success, isFalse);
      },
    );

    test('when progressStream consumes an empty stream, '
        'then it throws StateError and fails the parent only', () async {
      await expectLater(
        logger.progressStream<int>('P', const Stream<int>.empty()),
        throwsA(isA<StateError>()),
      );

      expect(writer.openedScopes.map((s) => s.label), ['P']);
      expect(writer.closedScopes.single.success, isFalse);
    });

    test('when info() is given a cli LogType, '
        'then the entry carries it in metadata', () async {
      logger.info('hello', type: cli.TextLogType.bullet);
      await logger.flush();

      final entry = writer.entries.single;
      expect(entry.message, 'hello');
      expect(entry.metadata?[logTypeKey], cli.TextLogType.bullet);
    });

    test('when log/write is called with cli.LogLevel.nothing, '
        'then it is suppressed, not an error', () async {
      logger.log('x', cli.LogLevel.nothing);
      logger.write('y', cli.LogLevel.nothing);
      await logger.flush();

      expect(writer.entries, isEmpty);
    });

    test('when error() is given a stack trace, '
        'then it stays structured on the entry', () async {
      final st = StackTrace.current;
      logger.error('bad', stackTrace: st);
      await logger.flush();

      final entry = writer.entries.single;
      expect(entry.level, LogLevel.error);
      expect(entry.message, 'bad', reason: 'message is not flattened');
      expect(entry.stackTrace, same(st));
    });

    test('when the logger is silenced (cli.LogLevel.nothing), '
        'then nothing is logged or scoped (the runner still runs)', () async {
      logger.logLevel = cli.LogLevel.nothing;

      logger.info('dropped');
      final result = await logger.progress('op', () async => true);
      await logger.flush();

      expect(result, isTrue, reason: 'runner still runs while silent');
      expect(writer.entries, isEmpty);
      expect(writer.openedScopes, isEmpty);
    });
  });
}
