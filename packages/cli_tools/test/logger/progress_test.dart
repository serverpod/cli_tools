import 'package:cli_tools/cli_tools.dart';
import 'package:test/test.dart';

import '../test_utils/io_helper.dart';

void main() {
  group('Given a StdOutLogger with info log level', () {
    final logger = StdOutLogger(LogLevel.info);

    group('when calling progress', () {
      test(
          'when runner completes successfully '
          'then runner result is returned and progress is marked successful',
          () async {
        bool? result;

        final (:stdout, :stderr, :stdin) = await collectOutput(() async {
          result = await logger.progress('Working', () async => true);
        });

        expect(result, isTrue);
        expect(stdout.output, contains('Working'));
        expect(stdout.output, contains('✓'));
        expect(stderr.output, isEmpty);
        expect(logger.trackedAnimationInProgress, isNull);
      });

      test(
          'when runner throws an exception '
          'then progress is marked failed and the exception is rethrown',
          () async {
        final (:stdout, :stderr, :stdin) = await collectOutput(() async {
          await expectLater(
            logger.progress('Working', () async => throw Exception('failed')),
            throwsA(isA<Exception>()),
          );
        });

        expect(stdout.output, contains('Working'));
        expect(stdout.output, contains('✗'));
        expect(stderr.output, isEmpty);
        expect(logger.trackedAnimationInProgress, isNull);
      });
    });

    group('when calling progressStream', () {
      test(
          'when stream has no events '
          'then StateError is thrown and progress is marked failed', () async {
        final (:stdout, :stderr, :stdin) = await collectOutput(() async {
          await expectLater(
            logger.progressStream<int>('Starting', const Stream<int>.empty()),
            throwsA(
              isA<StateError>().having(
                (final e) => e.message,
                'message',
                'No events in stream',
              ),
            ),
          );
        });

        expect(stdout.output, contains('Starting'));
        expect(stdout.output, contains('✗'));
        expect(stderr.output, isEmpty);
        expect(logger.trackedAnimationInProgress, isNull);
      });

      test(
          'when stream has a single event '
          'then the event is returned and progress is marked successful',
          () async {
        int? result;

        final (:stdout, :stderr, :stdin) = await collectOutput(() async {
          result = await logger.progressStream('Starting', Stream.value(42));
        });

        expect(result, 42);
        expect(stdout.output, contains('Starting'));
        expect(stdout.output, contains('42'));
        expect(stdout.output, contains('✓'));
        expect(stderr.output, isEmpty);
        expect(logger.trackedAnimationInProgress, isNull);
      });

      test(
          'when stream has several events '
          'then each event updates the message and the last event is returned',
          () async {
        int? result;

        final (:stdout, :stderr, :stdin) = await collectOutput(() async {
          result = await logger.progressStream(
            'Starting',
            Stream.fromIterable([1, 2, 3]),
            toMessage: (final step) => 'Step $step',
          );
        });

        expect(result, 3);
        expect(stdout.output, contains('Starting'));
        expect(stdout.output, contains('Step 1'));
        expect(stdout.output, contains('Step 2'));
        expect(stdout.output, contains('Step 3'));
        expect(stdout.output, contains('✓'));
        expect(stderr.output, isEmpty);
        expect(logger.trackedAnimationInProgress, isNull);
      });

      test(
          'when stream completes successfully '
          'then progress is marked successful', () async {
        final (:stdout, :stderr, :stdin) = await collectOutput(() async {
          await logger.progressStream(
            'Deploying',
            Stream.fromIterable(['build', 'deploy']),
            toMessage: (final phase) => phase,
          );
        });

        expect(stdout.output, contains('Deploying'));
        expect(stdout.output, contains('deploy'));
        expect(stdout.output, contains('✓'));
        expect(stdout.output, isNot(contains('✗')));
        expect(logger.trackedAnimationInProgress, isNull);
      });

      test(
          'when stream throws an exception '
          'then progress is marked failed and the exception is rethrown',
          () async {
        Stream<int> failingStream() async* {
          yield 1;
          throw Exception('stream failed');
        }

        final (:stdout, :stderr, :stdin) = await collectOutput(() async {
          await expectLater(
            logger.progressStream('Starting', failingStream()),
            throwsA(isA<Exception>()),
          );
        });

        expect(stdout.output, contains('Starting'));
        expect(stdout.output, contains('1'));
        expect(stdout.output, contains('✗'));
        expect(stdout.output, isNot(contains('✓')));
        expect(stderr.output, isEmpty);
        expect(logger.trackedAnimationInProgress, isNull);
      });

      test(
          'when newParagraph is true '
          'then a leading newline is written before progress output', () async {
        final (:stdout, :stderr, :stdin) = await collectOutput(() async {
          await logger.progressStream(
            'Starting',
            Stream.value('done'),
            newParagraph: true,
          );
        });

        expect(stdout.output, startsWith('\n'));
        expect(stdout.output, contains('✓'));
        expect(logger.trackedAnimationInProgress, isNull);
      });
    });
  });

  group('Given a StdOutLogger with warning log level', () {
    final logger = StdOutLogger(LogLevel.warning);

    test(
        'when calling progressStream '
        'then no progress output is written and the last event is returned',
        () async {
      int? result;

      final (:stdout, :stderr, :stdin) = await collectOutput(() async {
        result = await logger.progressStream(
          'Hidden',
          Stream.fromIterable([1, 2, 3]),
        );
      });

      expect(result, 3);
      expect(stdout.output, isEmpty);
      expect(stderr.output, isEmpty);
      expect(logger.trackedAnimationInProgress, isNull);
    });
  });
}
