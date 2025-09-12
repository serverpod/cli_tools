import 'package:cli_tools/better_command_runner.dart';
import 'package:test/test.dart';

void main() {
  group('Given BetterCommandRunner runner with onAnalyticsEvent', () {
    final runner = BetterCommandRunner(
      'test',
      'test description',
      onAnalyticsEvent: (final event) {},
      messageOutput: const MessageOutput(),
    );

    test(
      'when run with --verbose flag then runner completes successfully.',
      () async {
        final args = ['--verbose'];
        await expectLater(
          runner.run(args),
          completes,
          reason:
              'Expected runner to successfully parse and complete when run with --verbose flag.',
        );
      },
    );

    test('when run with -v flag then runner completes successfully.', () async {
      final args = ['-v'];
      await expectLater(
        runner.run(args),
        completes,
        reason:
            'Expected runner to successfully parse and complete when run with -v flag.',
      );
    });

    test(
      'when run with --quiet flag then runner completes successfully.',
      () async {
        final args = ['--quiet'];
        await expectLater(
          runner.run(args),
          completes,
          reason:
              'Expected runner to successfully parse and complete when run with --quiet flag.',
        );
      },
    );

    test('when run with -q flag then runner completes successfully.', () async {
      final args = ['-q'];
      await expectLater(
        runner.run(args),
        completes,
        reason:
            'Expected runner to successfully parse and complete when run with -q flag.',
      );
    });

    test(
      'when run with --analytics flag then runner completes successfully.',
      () async {
        final args = ['--analytics'];
        await expectLater(
          runner.run(args),
          completes,
          reason:
              'Expected runner to successfully parse and complete when run with --analytics flag.',
        );
      },
    );

    test('when run with -a flag then runner completes successfully.', () async {
      final args = ['-a'];
      await expectLater(
        runner.run(args),
        completes,
        reason:
            'Expected runner to successfully parse and complete when run with -a flag.',
      );
    });
  });
}
