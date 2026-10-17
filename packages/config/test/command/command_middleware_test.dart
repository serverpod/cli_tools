import 'package:config/command.dart';
import 'package:config/config.dart';
import 'package:test/test.dart';

import 'command_fixtures.dart';

void main() {
  group('Given a command with two middlewares', () {
    late List<String> trace;
    late CommandRunner runner;

    setUp(() {
      trace = [];
      final command = RecordingCommand<OptionDefinition>(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        middlewares: [
          (final next) => (final context) async {
            trace.add('outer-before');
            final result = await next(context);
            trace.add('outer-after');
            return 'outer:$result';
          },
          (final next) => (final context) async {
            trace.add('inner-before');
            final result = await next(context);
            trace.add('inner-after');
            return 'inner:$result';
          },
        ],
      );
      runner = CommandRunner<OptionDefinition, String>(
        'tool',
        'Tools',
        subcommands: [command],
      );
    });

    group('when the command runs', () {
      late String? result;

      setUp(() async {
        result = await runner.runner(['build']);
      });

      test('then the first middleware wraps the second', () {
        expect(trace, [
          'outer-before',
          'inner-before',
          'build',
          'inner-after',
          'outer-after',
        ]);
      });

      test('then the runner returns the outer middleware result', () {
        expect(result, 'outer:inner:build');
      });
    });
  });

  group('Given a synchronous command middleware', () {
    late List<String> trace;
    late CommandRunner runner;

    setUp(() {
      trace = [];
      final command = RecordingCommand<OptionDefinition>(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        middlewares: [
          (final next) => (final context) {
            trace.add('before');
            final result = next(context);
            trace.add('after:$result');
            return result;
          },
        ],
      );
      runner = CommandRunner<OptionDefinition, String>(
        'tool',
        'Tools',
        subcommands: [command],
      );
    });

    group('when the command runs', () {
      late String? result;

      setUp(() async {
        result = await runner.runner(['build']);
      });

      test('then the middleware runs around the command', () {
        expect(trace, ['before', 'build', 'after:build']);
      });

      test('then the command result is returned', () {
        expect(result, 'build');
      });
    });
  });

  group('Given middleware added after the command is created', () {
    test(
      'when the command runs '
      'then that middleware wraps the result',
      () async {
        final trace = <String>[];
        final command = RecordingCommand(
          name: 'build',
          description: 'Build the app',
          trace: trace,
        );
        command.addMiddleware(
          (final next) => (final context) async {
            final result = await next(context);
            return 'added:$result';
          },
        );
        final runner = CommandRunner(
          'tool',
          'Tools',
          subcommands: [command],
        );

        expect(await runner.runner(['build']), 'added:build');
      },
    );
  });

  group('Given command middleware that reads the run context', () {
    test(
      'when the command line sets an option '
      'then the middleware sees the resolved value',
      () async {
        const target = StringOption(argName: 'target');
        String? seen;
        final command = CommandImpl.withRunFunction<OptionDefinition, String>(
          name: 'build',
          description: 'Build the app',
          options: [target],
          middlewares: [
            (final next) => (final context) {
              seen = context.config.optionalValue(target);
              return next(context);
            },
          ],
          run: (final context) => 'build',
        );
        final runner = CommandRunner(
          'tool',
          'Tools',
          subcommands: [command],
        );

        await runner.runner(['build', '--target', 'wasm']);

        expect(seen, 'wasm');
      },
    );
  });

  group('Given middleware that replaces the run context', () {
    const marker = StringOption(argName: 'marker');

    late RunCommandContext<OptionDefinition, String> replaced;
    late RunCommandContext<OptionDefinition, String>? seenByCommand;
    late String? result;

    setUp(() async {
      seenByCommand = null;
      final command = CommandImpl.withRunFunction<OptionDefinition, String>(
        name: 'build',
        description: 'Build the app',
        middlewares: [
          (final next) => (final context) {
            replaced = context.copyWith(
              config: Configuration.fromValues(
                values: {marker: 'from-middleware'},
              ),
            );
            return next(replaced);
          },
        ],
        run: (final context) {
          seenByCommand = context;
          return context.config.optionalValue(marker);
        },
      );
      final runner = CommandRunner(
        'tool',
        'Tools',
        subcommands: [command],
      );
      result = await runner.runner(['build']);
    });

    test(
      'when the command runs '
      'then the command receives the replaced context',
      () {
        expect(seenByCommand, same(replaced));
      },
    );

    test(
      'when the command runs '
      'then the command result is returned',
      () {
        expect(result, 'from-middleware');
      },
    );
  });

  group(
    'Given middleware that replaces the context passed to a following command',
    () {
      const marker = StringOption(argName: 'marker');

      late _MarkerProvider originalProvider;
      late _MarkerProvider replacedProvider;
      late RunCommandContext<OptionDefinition, String> replaced;
      late RunCommandContext<OptionDefinition, String>? seenByCheck;
      late String? result;

      setUp(() async {
        originalProvider = _MarkerProvider();
        replacedProvider = _MarkerProvider();
        seenByCheck = null;
        final check = CommandImpl.withRunFunction<OptionDefinition, String>(
          name: 'check',
          description: 'Check the app',
          middlewares: [
            (final next) => (final context) {
              seenByCheck = context;
              return next(context);
            },
          ],
          run: (final context) => 'check',
        );
        final build = CommandImpl.withRunFunction<OptionDefinition, String>(
          name: 'build',
          description: 'Build the app',
          subcommands: [check],
          middlewares: [
            (final next) => (final context) {
              final following = context.next;
              if (following == null) {
                throw StateError('build has no following command.');
              }
              replaced = following.copyWith(
                config: Configuration.fromValues(
                  values: {marker: 'from-middleware'},
                ),
                provider: replacedProvider,
              );
              return next(context.copyWith(next: replaced));
            },
          ],
          run: (final context) => 'build',
        );
        final runner = CommandRunner(
          'tool',
          'Tools',
          subcommands: [build],
        );
        result = await runner.runner(
          ['build', 'check'],
          provider: originalProvider,
        );
      });

      test(
        'when the nested command line runs '
        'then the following command receives the replaced context',
        () {
          expect(seenByCheck, same(replaced));
        },
      );

      test(
        'when the nested command line runs '
        'then the following command result is returned',
        () {
          expect(result, 'check');
        },
      );
    },
  );

  group('Given command middleware that does not call the command', () {
    late List<String> trace;
    late TracingRunner runner;

    setUp(() {
      trace = [];
      final command = RecordingCommand(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        middlewares: [
          (final next) =>
              (final context) => 'stopped',
        ],
      );
      runner = TracingRunner(trace, subcommands: [command]);
    });

    group('when the command line is run', () {
      late String? result;

      setUp(() async {
        result = await runner.runner(['build']);
      });

      test('then the command body does not run', () {
        expect(trace, isEmpty);
      });

      test('then the middleware result is returned', () {
        expect(result, 'stopped');
      });
    });
  });

  group('Given a runner middleware and a command middleware', () {
    late List<String> trace;
    late TracingRunner runner;

    setUp(() {
      trace = [];
      final command = RecordingCommand<OptionDefinition>(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        middlewares: [
          (final next) => (final context) async {
            trace.add('cmd-before');
            final result = await next(context);
            trace.add('cmd-after');
            return 'cmd:$result';
          },
        ],
      );
      runner = TracingRunner(
        trace,
        middlewares: [
          (final next) => (final context) async {
            trace.add('root-before');
            final result = await next(context);
            trace.add('root-after:$result');
            return result;
          },
        ],
        subcommands: [command],
      );
    });

    group('when the command line is run', () {
      late String? result;

      setUp(() async {
        result = await runner.runner(['build']);
      });

      test(
        'then the runner middleware wraps the root command and the subcommand',
        () {
          expect(trace, [
            'root-before',
            'cmd-before',
            'build',
            'cmd-after',
            'root-after:cmd:build',
          ]);
        },
      );

      test('then the runner returns the command middleware result', () {
        expect(result, 'cmd:build');
      });
    });
  });

  group('Given runner middleware that does not call the root command', () {
    late List<String> trace;
    late TracingRunner runner;

    setUp(() {
      trace = [];
      runner = TracingRunner(
        trace,
        middlewares: [
          (final next) =>
              (final context) => 'skipped-root',
        ],
        subcommands: [
          RecordingCommand(
            name: 'build',
            description: 'Build the app',
            trace: trace,
          ),
        ],
      );
    });

    group('when the command line is run', () {
      late String? result;

      setUp(() async {
        result = await runner.runner(['build']);
      });

      test('then the root command and its subcommands do not run', () {
        expect(trace, isEmpty);
      });

      test('then the middleware result is returned', () {
        expect(result, 'skipped-root');
      });
    });
  });

  group('Given runner middleware that throws', () {
    late List<String> trace;
    late TracingRunner runner;
    late Object? error;

    setUp(() async {
      trace = [];
      error = null;
      runner = TracingRunner(
        trace,
        middlewares: [
          (final next) =>
              (final context) => throw StateError('stop'),
        ],
        subcommands: [
          RecordingCommand(
            name: 'build',
            description: 'Build the app',
            trace: trace,
          ),
        ],
      );
      try {
        await runner.runner(['build']);
      } on StateError catch (e) {
        error = e;
      }
    });

    test('when the command line is run then the failure is reported', () {
      expect(error, isA<StateError>());
    });

    test('when the command line is run then the subcommand does not run', () {
      expect(trace, isEmpty);
    });
  });

  group('Given a standalone command with its own middleware', () {
    late List<String> trace;
    late TracingRunner runner;

    setUp(() async {
      trace = [];
      final child = RecordingCommand<OptionDefinition>(
        name: 'version',
        description: 'Show the version',
        trace: trace,
        standalone: true,
        middlewares: [
          (final next) => (final context) async {
            trace.add('version-before');
            final result = await next(context);
            trace.add('version-after');
            return result;
          },
        ],
      );
      final parent = RecordingCommand<OptionDefinition>(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        middlewares: [
          (final next) => (final context) async {
            trace.add('build-before');
            return next(context);
          },
        ],
        subcommands: [child],
      );
      runner = TracingRunner(
        trace,
        middlewares: [
          (final next) => (final context) async {
            trace.add('root-before');
            return next(context);
          },
        ],
        subcommands: [parent],
      );
      await runner.runner(['build', 'version']);
    });

    test(
      'when the standalone command is last '
      'then only that command and its middleware run',
      () {
        expect(trace, ['version-before', 'version', 'version-after']);
      },
    );
  });

  group('Given middleware on the runner, a command, and a subcommand', () {
    late List<String> trace;
    late String? result;

    setUp(() async {
      trace = [];
      final child = RecordingCommand<OptionDefinition>(
        name: 'check',
        description: 'Check the app',
        trace: trace,
        middlewares: [
          (final next) => (final context) async {
            trace.add('check-before');
            final value = await next(context);
            trace.add('check-after');
            return 'check:$value';
          },
        ],
      );
      final parent = RecordingCommand<OptionDefinition>(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        subcommands: [child],
        middlewares: [
          (final next) => (final context) async {
            trace.add('build-before');
            final value = await next(context);
            trace.add('build-after');
            return 'build:$value';
          },
        ],
      );
      final runner = TracingRunner<OptionDefinition>(
        trace,
        middlewares: [
          (final next) => (final context) async {
            trace.add('root-before');
            final value = await next(context);
            trace.add('root-after');
            return 'root:$value';
          },
        ],
        subcommands: [parent],
      );
      result = await runner.runner(['build', 'check']);
    });

    test('then each middleware wraps that command and its subcommands', () {
      expect(trace, [
        'root-before',
        'build-before',
        'check-before',
        'check',
        'check-after',
        'build-after',
        'root-after',
      ]);
    });

    test('then the runner returns the outermost middleware result', () {
      expect(result, 'root:build:check:check');
    });
  });

  group('Given synchronous middleware on a command with a subcommand', () {
    late List<String> trace;
    late String? result;

    setUp(() async {
      trace = [];
      final child = RecordingCommand<OptionDefinition>(
        name: 'check',
        description: 'Check the app',
        trace: trace,
      );
      final parent = RecordingCommand<OptionDefinition>(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        subcommands: [child],
        middlewares: [
          (final next) => (final context) {
            trace.add('before');
            final value = next(context);
            trace.add('after:$value');
            return value;
          },
        ],
      );
      final runner = TracingRunner(trace, subcommands: [parent]);
      result = await runner.runner(['build', 'check']);
    });

    test('then the middleware wraps the command and the subcommand', () {
      expect(trace, ['before', 'check', 'after:check']);
    });

    test('then the subcommand result is returned', () {
      expect(result, 'check');
    });
  });

  group('Given command middleware that does not call the next handler', () {
    late List<String> trace;
    late String? result;

    setUp(() async {
      trace = [];
      final child = RecordingCommand<OptionDefinition>(
        name: 'check',
        description: 'Check the app',
        trace: trace,
      );
      final parent = RecordingCommand<OptionDefinition>(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        subcommands: [child],
        middlewares: [
          (final next) => (final context) async {
            trace.add('build-before');
            return 'stopped';
          },
        ],
      );
      final runner = TracingRunner<OptionDefinition>(
        trace,
        middlewares: [
          (final next) => (final context) async {
            trace.add('root-before');
            final value = await next(context);
            trace.add('root-after:$value');
            return value;
          },
        ],
        subcommands: [parent],
      );
      result = await runner.runner(['build', 'check']);
    });

    test('then that command and its subcommands do not run', () {
      expect(trace, [
        'root-before',
        'build-before',
        'root-after:stopped',
      ]);
    });

    test('then the middleware result is returned', () {
      expect(result, 'stopped');
    });
  });

  group('Given a parent command whose body finishes asynchronously', () {
    late List<String> trace;
    late String? result;

    setUp(() async {
      trace = [];
      final child = RecordingCommand<OptionDefinition>(
        name: 'check',
        description: 'Check the app',
        trace: trace,
      );
      final parent = RecordingCommand<OptionDefinition>(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        subcommands: [child],
        body: (final context) async {
          trace.add('build-body-start');
          await Future<void>.delayed(Duration.zero);
          trace.add('build-body-end');
          return 'build-body';
        },
      );
      final runner = TracingRunner(trace, subcommands: [parent]);
      result = await runner.runner(['build', 'check']);
    });

    test('then the parent body does not run', () {
      expect(trace, ['check']);
    });

    test('then the subcommand result is returned', () {
      expect(result, 'check');
    });
  });
}

class _MarkerProvider implements ContextProvider {
  @override
  T fetch<T extends Object>() => throw StateError('No value stored for $T.');

  @override
  void store<T extends Object>(final T value) {}

  @override
  void remove<T extends Object>(final T value) {}
}
