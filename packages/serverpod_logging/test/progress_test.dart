import 'package:serverpod_logging/serverpod_logging.dart';
import 'package:test/test.dart';

import 'test_utils/io_helper.dart';

void main() {
  group('Given a Log with TextLogWriter and info log level', () {
    final log = Log(TextLogWriter(), logLevel: LogLevel.info);

    group('when calling progress', () {
      test(
        'when runner completes successfully '
        'then runner result is returned and progress is marked successful',
        () async {
          bool? result;

          final (:stdout, :stderr, :stdin) = await collectOutput(() async {
            result = await log.progress('Working', () async => true);
          });

          expect(result, isTrue);
          expect(stdout.output, contains('Working'));
          expect(stdout.output, contains('✓'));
          expect(stderr.output, isEmpty);
        },
      );

      test(
        'when runner completes unsuccessfully '
        'then runner result is returned and progress is marked unsuccessful',
        () async {
          bool? result;

          final (:stdout, :stderr, :stdin) = await collectOutput(() async {
            result = await log.progress('Working', () async => false);
          });

          expect(result, isFalse);
          expect(stdout.output, contains('Working'));
          expect(stdout.output, contains('✗'));
          expect(stderr.output, isEmpty);
        },
      );

      test(
        'when runner throws an exception '
        'then progress is marked failed and the exception is rethrown',
        () async {
          final (:stdout, :stderr, :stdin) = await collectOutput(() async {
            await expectLater(
              log.progress('Working', () async => throw Exception('failed')),
              throwsA(isA<Exception>()),
            );
          });

          expect(stdout.output, contains('Working'));
          expect(stdout.output, contains('✗'));
          expect(stderr.output, isEmpty);
        },
      );
    });

    group('when calling progressStream', () {
      test('when stream has no events '
          'then StateError is thrown and progress is marked failed', () async {
        final (:stdout, :stderr, :stdin) = await collectOutput(() async {
          await expectLater(
            log.progressStream<int>('Starting', const Stream<int>.empty()),
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
      });

      test(
        'when stream has a single event '
        'then the event is returned and progress is marked successful',
        () async {
          int? result;

          final (:stdout, :stderr, :stdin) = await collectOutput(() async {
            result = await log.progressStream('Starting', Stream.value(42));
          });

          expect(result, 42);
          expect(stdout.output, contains('Starting'));
          expect(stdout.output, contains('42'));
          expect(stdout.output, contains('✓'));
          expect(stderr.output, isEmpty);
        },
      );

      test(
        'when stream has several events '
        'then each event updates the message and the last event is returned',
        () async {
          int? result;

          final (:stdout, :stderr, :stdin) = await collectOutput(() async {
            result = await log.progressStream(
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
        },
      );

      test('when stream completes successfully '
          'then progress is marked successful', () async {
        final (:stdout, :stderr, :stdin) = await collectOutput(() async {
          await log.progressStream(
            'Deploying',
            Stream.fromIterable(['build', 'deploy']),
            toMessage: (final phase) => phase,
          );
        });

        expect(stdout.output, contains('Deploying'));
        expect(stdout.output, contains('deploy'));
        expect(stdout.output, contains('✓'));
        expect(stdout.output, isNot(contains('✗')));
      });

      test('when stream completes and result is successful '
          'then progress is marked successful', () async {
        final (:stdout, :stderr, :stdin) = await collectOutput(() async {
          await log.progressStream(
            'Deploying',
            Stream.fromIterable(['build', 'deploy']),
            toMessage: (final phase) => phase,
            isSuccess: (final phase) => phase == 'deploy',
          );
        });

        expect(stdout.output, contains('Deploying'));
        expect(stdout.output, contains('deploy'));
        expect(stdout.output, contains('✓'));
        expect(stdout.output, isNot(contains('✗')));
      });

      test('when stream completes but result is not successful '
          'then progress is marked unsuccessful', () async {
        final (:stdout, :stderr, :stdin) = await collectOutput(() async {
          await log.progressStream(
            'Deploying',
            Stream.fromIterable(['build', 'deploy']),
            toMessage: (final phase) => phase,
            isSuccess: (final phase) => phase == 'some-other-phase',
          );
        });

        expect(stdout.output, contains('Deploying'));
        expect(stdout.output, contains('deploy'));
        expect(stdout.output, contains('✗'));
        expect(stdout.output, isNot(contains('✓')));
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
              log.progressStream('Starting', failingStream()),
              throwsA(isA<Exception>()),
            );
          });

          expect(stdout.output, contains('Starting'));
          expect(stdout.output, contains('1'));
          expect(stdout.output, contains('✗'));
          expect(stdout.output, isNot(contains('✓')));
          expect(stderr.output, isEmpty);
        },
      );
    });
  });
}
