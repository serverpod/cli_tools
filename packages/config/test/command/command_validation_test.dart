import 'package:config/command.dart';
import 'package:config/config.dart';
import 'package:test/test.dart';

import 'command_fixtures.dart';

void main() {
  group('Given two subcommands with the same name', () {
    late List<String> trace;
    late StringBuffer out;
    late StringBuffer err;
    late int usageHandlerCalls;
    late TracingRunner runner;

    setUp(() {
      trace = [];
      out = StringBuffer();
      err = StringBuffer();
      usageHandlerCalls = 0;
      final first = RecordingCommand(
        name: 'build',
        description: 'Build the app',
        trace: trace,
      );
      final second = RecordingCommand(
        name: 'build',
        description: 'Build again',
        trace: trace,
      );
      runner = TracingRunner(
        trace,
        middlewares: [
          (final next) => (final context) {
            trace.add('root');
            return next(context);
          },
        ],
        usageOutput: UsageOutputHandler(
          sinks: UsageSinks(out: out, err: err),
          addExceptionHandlers: [
            (
              final UsageException exception,
              final UsageOutputHandler usageOutput, {
              required final CommandDefinition? fromCommand,
            }) {
              usageHandlerCalls++;
              return exception;
            },
          ],
        ),
        subcommands: [first, second],
      );
    });

    group('when the command line would also be invalid', () {
      late Object? error;

      setUp(() async {
        error = null;
        try {
          await runner.execute(['missing', '--missing']);
        } catch (e) {
          error = e;
        }
      });

      test('then a definition error is thrown', () {
        expect(error, isA<ConfigDefinitionError>());
      });

      test('then the duplicate command name is reported', () {
        expect(
          error.toString(),
          'CommandDefinitionError: Invalid definition for command `build`: '
          'Duplicate subcommand name: build for command tool',
        );
      });

      test('then usage is not printed', () {
        expect(out.toString(), isEmpty);
        expect(err.toString(), isEmpty);
      });

      test('then usage exception handlers are not called', () {
        expect(usageHandlerCalls, 0);
      });

      test('then no command or middleware runs', () {
        expect(trace, isEmpty);
      });
    });
  });

  group('Given a branch command with a positional option', () {
    late List<String> trace;
    late StringBuffer err;
    late Object? error;

    setUp(() async {
      trace = [];
      err = StringBuffer();
      error = null;
      final child = RecordingCommand(
        name: 'check',
        description: 'Check the app',
        trace: trace,
      );
      final parent = RecordingCommand<OptionDefinition>(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        options: const [
          StringOption(argName: 'file', argPos: 0),
        ],
        subcommands: [child],
        middlewares: [
          (final next) => (final context) {
            trace.add('middleware');
            return next(context);
          },
        ],
      );
      final runner = TracingRunner(
        trace,
        usageOutput: UsageOutputHandler(sinks: UsageSinks(err: err)),
        subcommands: [parent],
      );
      try {
        await runner.execute(['build', 'check']);
      } catch (e) {
        error = e;
      }
    });

    test('when the runner is started then a definition error is thrown', () {
      expect(
        error,
        isA<CommandDefinitionError>().having(
          (final error) => error.toString(),
          'toString',
          'CommandDefinitionError: Invalid definition for command `build`: '
              'Cannot define positional options on a command with subcommands: '
              'option `file`.',
        ),
      );
    });

    test('when the runner is started then usage is not printed', () {
      expect(err.toString(), isEmpty);
    });

    test(
      'when the runner is started '
      'then no command or middleware runs',
      () {
        expect(trace, isEmpty);
      },
    );
  });

  group('Given a command with two options of the same name', () {
    late List<String> trace;
    late StringBuffer err;
    late Object? error;

    setUp(() async {
      trace = [];
      err = StringBuffer();
      error = null;
      final command = RecordingCommand<OptionDefinition>(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        options: const [
          StringOption(argName: 'target'),
          StringOption(argName: 'target'),
        ],
        middlewares: [
          (final next) => (final context) {
            trace.add('middleware');
            return next(context);
          },
        ],
      );
      final runner = TracingRunner(
        trace,
        usageOutput: UsageOutputHandler(sinks: UsageSinks(err: err)),
        subcommands: [command],
      );
      try {
        await runner.execute(['build', '--missing']);
      } catch (e) {
        error = e;
      }
    });

    test('when the runner is started then a definition error is thrown', () {
      expect(
        error,
        isA<OptionDefinitionError>().having(
          (final error) => error.toString(),
          'toString',
          'OptionDefinitionError: Invalid definition for option `target`: '
              'Duplicate argument name: target for target',
        ),
      );
    });

    test('when the runner is started then usage is not printed', () {
      expect(err.toString(), isEmpty);
    });

    test(
      'when the runner is started '
      'then no command or middleware runs',
      () {
        expect(trace, isEmpty);
      },
    );
  });
}
