import 'dart:async' show FutureOr;

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
        result = await runner.run(['build']);
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
        result = await runner.run(['build']);
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

        expect(await runner.run(['build']), 'added:build');
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
        final command =
            CommandImpl.leafWithRunFunction<OptionDefinition, String>(
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

        await runner.run(['build', '--target', 'wasm']);

        expect(seen, 'wasm');
      },
    );
  });

  group('Given middleware that replaces the run context', () {
    const marker = StringOption(argName: 'marker');

    late CommandContext<OptionDefinition, String> replaced;
    late CommandContext<OptionDefinition, String>? seenByCommand;
    late String? result;

    setUp(() async {
      seenByCommand = null;
      final command = CommandImpl.leafWithRunFunction<OptionDefinition, String>(
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
      result = await runner.run(['build']);
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
      late CommandContext<OptionDefinition, String> replaced;
      late CommandContext<OptionDefinition, String>? seenByCheck;
      late String? result;

      setUp(() async {
        originalProvider = _MarkerProvider();
        replacedProvider = _MarkerProvider();
        seenByCheck = null;
        final check = CommandImpl.leafWithRunFunction<OptionDefinition, String>(
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
        final build = CommandImpl.branch<OptionDefinition, String>(
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
        );
        final runner = CommandRunner(
          'tool',
          'Tools',
          subcommands: [build],
        );
        result = await runner.run(
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
        result = await runner.run(['build']);
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
        result = await runner.run(['build']);
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
        result = await runner.run(['build']);
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
    late StringBuffer err;
    late TracingRunner runner;
    late Object? error;

    setUp(() async {
      trace = [];
      err = StringBuffer();
      error = null;
      runner = TracingRunner(
        trace,
        usageOutput: UsageOutputHandler(sinks: OutputSinks(err: err)),
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
        await runner.run(['build']);
      } on StateError catch (e) {
        error = e;
      }
    });

    test('when the command line is run then the failure is reported', () {
      expect(
        error,
        isA<StateError>().having(
          (final error) => error.message,
          'message',
          'stop',
        ),
      );
    });

    test('when the command line is run then the subcommand does not run', () {
      expect(trace, isEmpty);
    });

    test('when the command line is run then usage is not printed', () {
      expect(err.toString(), isEmpty);
    });
  });

  group('Given a command whose body throws', () {
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
        body: (final context) => throw StateError('boom'),
        middlewares: [
          (final next) => (final context) async {
            trace.add('before');
            final result = await next(context);
            trace.add('after');
            return result;
          },
        ],
      );
      final runner = TracingRunner(
        trace,
        usageOutput: UsageOutputHandler(sinks: OutputSinks(err: err)),
        subcommands: [command],
      );
      try {
        await runner.run(['build']);
      } on StateError catch (e) {
        error = e;
      }
    });

    test(
      'when the command line is run then the failure reaches the caller',
      () {
        expect(
          error,
          isA<StateError>().having(
            (final error) => error.message,
            'message',
            'boom',
          ),
        );
      },
    );

    test(
      'when the command line is run '
      'then middleware does not continue after the command',
      () {
        expect(trace, ['before', 'build']);
      },
    );

    test('when the command line is run then usage is not printed', () {
      expect(err.toString(), isEmpty);
    });
  });

  group('Given command middleware that handles a command failure', () {
    late List<String> trace;
    late StringBuffer err;
    late String? result;

    setUp(() async {
      trace = [];
      err = StringBuffer();
      final command = RecordingCommand<OptionDefinition>(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        body: (final context) => throw StateError('boom'),
        middlewares: [
          (final next) => (final context) async {
            trace.add('before');
            try {
              return await next(context);
            } on StateError {
              trace.add('handled');
              return 'recovered';
            }
          },
        ],
      );
      final runner = TracingRunner(
        trace,
        usageOutput: UsageOutputHandler(sinks: OutputSinks(err: err)),
        subcommands: [command],
      );
      result = await runner.run(['build']);
    });

    test(
      'when the command line is run '
      'then the middleware result is returned',
      () {
        expect(result, 'recovered');
      },
    );

    test(
      'when the command line is run '
      'then the middleware runs around the failure',
      () {
        expect(trace, ['before', 'build', 'handled']);
      },
    );

    test('when the command line is run then usage is not printed', () {
      expect(err.toString(), isEmpty);
    });
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
      result = await runner.run(['build', 'check']);
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
      result = await runner.run(['build', 'check']);
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
      result = await runner.run(['build', 'check']);
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
      result = await runner.run(['build', 'check']);
    });

    test('then the parent body does not run', () {
      expect(trace, ['check']);
    });

    test('then the subcommand result is returned', () {
      expect(result, 'check');
    });
  });

  group('Given Middlewares.onBeforeRun with a synchronous callback', () {
    late List<String> trace;
    late String? result;

    setUp(() async {
      trace = [];
      final command = RecordingCommand<OptionDefinition>(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        middlewares: [
          Middlewares.onBeforeRun((final _) {
            trace.add('before');
          }),
        ],
      );
      final runner = CommandRunner<OptionDefinition, String>(
        'tool',
        'Tools',
        subcommands: [command],
      );
      result = await runner.run(['build']);
    });

    test(
      'when the command runs then the callback runs before the command',
      () {
        expect(trace, ['before', 'build']);
      },
    );

    test('when the command runs then the command result is returned', () {
      expect(result, 'build');
    });
  });

  group('Given Middlewares.onBeforeRun with an asynchronous callback', () {
    late List<String> trace;
    late String? result;

    setUp(() async {
      trace = [];
      final command = RecordingCommand<OptionDefinition>(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        middlewares: [
          Middlewares.onBeforeRun((final _) async {
            trace.add('before-start');
            await Future<void>.delayed(Duration.zero);
            trace.add('before-end');
          }),
        ],
      );
      final runner = CommandRunner<OptionDefinition, String>(
        'tool',
        'Tools',
        subcommands: [command],
      );
      result = await runner.run(['build']);
    });

    test(
      'when the command runs then the callback finishes before the command',
      () {
        expect(trace, ['before-start', 'before-end', 'build']);
      },
    );

    test('when the command runs then the command result is returned', () {
      expect(result, 'build');
    });
  });

  group('Given Middlewares.onRun with a synchronous callback', () {
    const marker = StringOption(argName: 'marker');

    late String? seen;
    late String? result;

    setUp(() async {
      seen = null;
      final command = CommandImpl.leafWithRunFunction<OptionDefinition, String>(
        name: 'build',
        description: 'Build the app',
        middlewares: [
          Middlewares.onRun((final context) {
            return context.copyWith(
              config: Configuration.fromValues(
                values: {marker: 'from-hook'},
              ),
            );
          }),
        ],
        run: (final context) {
          seen = context.config.optionalValue(marker);
          return 'build';
        },
      );
      final runner = CommandRunner(
        'tool',
        'Tools',
        subcommands: [command],
      );
      result = await runner.run(['build']);
    });

    test(
      'when the command runs '
      'then the command receives the context from the callback',
      () {
        expect(seen, 'from-hook');
      },
    );

    test('when the command runs then the command result is returned', () {
      expect(result, 'build');
    });
  });

  group('Given Middlewares.onRun with an asynchronous callback', () {
    const marker = StringOption(argName: 'marker');

    late String? seen;
    late String? result;

    setUp(() async {
      seen = null;
      final command = CommandImpl.leafWithRunFunction<OptionDefinition, String>(
        name: 'build',
        description: 'Build the app',
        middlewares: [
          Middlewares.onRun((final context) async {
            await Future<void>.delayed(Duration.zero);
            return context.copyWith(
              config: Configuration.fromValues(
                values: {marker: 'from-hook'},
              ),
            );
          }),
        ],
        run: (final context) {
          seen = context.config.optionalValue(marker);
          return 'build';
        },
      );
      final runner = CommandRunner(
        'tool',
        'Tools',
        subcommands: [command],
      );
      result = await runner.run(['build']);
    });

    test(
      'when the command runs '
      'then the command receives the context from the callback',
      () {
        expect(seen, 'from-hook');
      },
    );

    test('when the command runs then the command result is returned', () {
      expect(result, 'build');
    });
  });

  group('Given Middlewares.onReturn with a synchronous callback', () {
    late List<String> trace;
    late String? result;

    setUp(() async {
      trace = [];
      final command = RecordingCommand<OptionDefinition>(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        middlewares: [
          Middlewares.onReturn((final _, final response) {
            trace.add('onReturn');
            return 'hook:$response';
          }),
        ],
      );
      final runner = CommandRunner<OptionDefinition, String>(
        'tool',
        'Tools',
        subcommands: [command],
      );
      result = await runner.run(['build']);
    });

    test(
      'when the command runs then the callback runs after the command',
      () {
        expect(trace, ['build', 'onReturn']);
      },
    );

    test('when the command runs then the callback value is returned', () {
      expect(result, 'hook:build');
    });
  });

  group('Given Middlewares.onReturn with an asynchronous callback', () {
    late List<String> trace;
    late String? result;

    setUp(() async {
      trace = [];
      final command = RecordingCommand<OptionDefinition>(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        middlewares: [
          Middlewares.onReturn((final _, final response) async {
            trace.add('onReturn-start');
            await Future<void>.delayed(Duration.zero);
            trace.add('onReturn-end');
            return 'hook:$response';
          }),
        ],
      );
      final runner = CommandRunner<OptionDefinition, String>(
        'tool',
        'Tools',
        subcommands: [command],
      );
      result = await runner.run(['build']);
    });

    test(
      'when the command runs then the callback finishes after the command',
      () {
        expect(trace, ['build', 'onReturn-start', 'onReturn-end']);
      },
    );

    test('when the command runs then the callback value is returned', () {
      expect(result, 'hook:build');
    });
  });

  group('Given Middlewares.onError with a synchronous callback', () {
    late List<String> trace;
    late String? result;

    setUp(() async {
      trace = [];
      final command = RecordingCommand<OptionDefinition>(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        body: (final _) => throw StateError('boom'),
        middlewares: [
          Middlewares.onError((final error, final _, final _) {
            trace.add('onError');
            return 'recovered:${(error as StateError).message}';
          }),
        ],
      );
      final runner = CommandRunner<OptionDefinition, String>(
        'tool',
        'Tools',
        subcommands: [command],
      );
      result = await runner.run(['build']);
    });

    test(
      'when the command fails then the callback runs after the command',
      () {
        expect(trace, ['build', 'onError']);
      },
    );

    test('when the command fails then the callback value is returned', () {
      expect(result, 'recovered:boom');
    });
  });

  group('Given Middlewares.onError with an asynchronous callback', () {
    late List<String> trace;
    late String? result;

    setUp(() async {
      trace = [];
      final command = RecordingCommand<OptionDefinition>(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        body: (final _) => throw StateError('boom'),
        middlewares: [
          Middlewares.onError((final error, final _, final _) async {
            trace.add('onError-start');
            await Future<void>.delayed(Duration.zero);
            trace.add('onError-end');
            return 'recovered:${(error as StateError).message}';
          }),
        ],
      );
      final runner = CommandRunner<OptionDefinition, String>(
        'tool',
        'Tools',
        subcommands: [command],
      );
      result = await runner.run(['build']);
    });

    test(
      'when the command fails then the callback finishes after the command',
      () {
        expect(trace, ['build', 'onError-start', 'onError-end']);
      },
    );

    test('when the command fails then the callback value is returned', () {
      expect(result, 'recovered:boom');
    });
  });

  group('Given Middlewares.onFinally with a synchronous callback', () {
    late List<String> trace;
    late String? result;

    setUp(() async {
      trace = [];
      final command = RecordingCommand<OptionDefinition>(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        middlewares: [
          Middlewares.onFinally((final _) {
            trace.add('onFinally');
          }),
        ],
      );
      final runner = CommandRunner<OptionDefinition, String>(
        'tool',
        'Tools',
        subcommands: [command],
      );
      result = await runner.run(['build']);
    });

    test(
      'when the command runs then the callback runs after the command',
      () {
        expect(trace, ['build', 'onFinally']);
      },
    );

    test('when the command runs then the command result is returned', () {
      expect(result, 'build');
    });
  });

  group('Given Middlewares.onFinally with an asynchronous callback', () {
    late List<String> trace;
    late String? result;

    setUp(() async {
      trace = [];
      final command = RecordingCommand<OptionDefinition>(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        middlewares: [
          Middlewares.onFinally((final _) async {
            trace.add('onFinally-start');
            await Future<void>.delayed(Duration.zero);
            trace.add('onFinally-end');
          }),
        ],
      );
      final runner = CommandRunner<OptionDefinition, String>(
        'tool',
        'Tools',
        subcommands: [command],
      );
      result = await runner.run(['build']);
    });

    test(
      'when the command runs then the callback finishes after the command',
      () {
        expect(trace, ['build', 'onFinally-start', 'onFinally-end']);
      },
    );

    test('when the command runs then the command result is returned', () {
      expect(result, 'build');
    });
  });

  group(
    'Given Middlewares.onFinally with a synchronous callback '
    'on a failing command',
    () {
      late List<String> trace;
      late Object? error;

      setUp(() async {
        trace = [];
        error = null;
        final command = RecordingCommand<OptionDefinition>(
          name: 'build',
          description: 'Build the app',
          trace: trace,
          body: (final _) => throw StateError('boom'),
          middlewares: [
            Middlewares.onFinally((final _) {
              trace.add('onFinally');
            }),
          ],
        );
        final runner = CommandRunner<OptionDefinition, String>(
          'tool',
          'Tools',
          subcommands: [command],
        );
        try {
          await runner.run(['build']);
        } on StateError catch (thrown) {
          error = thrown;
        }
      });

      test(
        'when the command fails then the callback runs after the command',
        () {
          expect(trace, ['build', 'onFinally']);
        },
      );

      test('when the command fails then the exception propagates', () {
        expect(
          error,
          isA<StateError>().having(
            (final error) => error.message,
            'message',
            'boom',
          ),
        );
      });
    },
  );

  group(
    'Given Middlewares.onFinally with an asynchronous callback '
    'on a failing command',
    () {
      late List<String> trace;
      late Object? error;

      setUp(() async {
        trace = [];
        error = null;
        final command = RecordingCommand<OptionDefinition>(
          name: 'build',
          description: 'Build the app',
          trace: trace,
          body: (final _) => throw StateError('boom'),
          middlewares: [
            Middlewares.onFinally((final _) async {
              trace.add('onFinally-start');
              await Future<void>.delayed(Duration.zero);
              trace.add('onFinally-end');
            }),
          ],
        );
        final runner = CommandRunner<OptionDefinition, String>(
          'tool',
          'Tools',
          subcommands: [command],
        );
        try {
          await runner.run(['build']);
        } on StateError catch (thrown) {
          error = thrown;
        }
      });

      test(
        'when the command fails then the callback finishes after the command',
        () {
          expect(trace, ['build', 'onFinally-start', 'onFinally-end']);
        },
      );

      test('when the command fails then the exception propagates', () {
        expect(
          error,
          isA<StateError>().having(
            (final error) => error.message,
            'message',
            'boom',
          ),
        );
      });
    },
  );

  group(
    'Given Middlewares.onFinally with a synchronous callback that throws',
    () {
      late List<String> trace;
      late String? result;

      setUp(() async {
        trace = [];
        final command = RecordingCommand<OptionDefinition>(
          name: 'build',
          description: 'Build the app',
          trace: trace,
          middlewares: [
            Middlewares.onFinally((final _) {
              trace.add('onFinally');
              throw StateError('onFinally');
            }),
          ],
        );
        final runner = CommandRunner<OptionDefinition, String>(
          'tool',
          'Tools',
          subcommands: [command],
        );
        result = await runner.run(['build']);
      });

      test(
        'when the command runs then the callback runs after the command',
        () {
          expect(trace, ['build', 'onFinally']);
        },
      );

      test('when the command runs then the command result is returned', () {
        expect(result, 'build');
      });
    },
  );

  group(
    'Given Middlewares.onFinally with an asynchronous callback that throws',
    () {
      late List<String> trace;
      late String? result;

      setUp(() async {
        trace = [];
        final command = RecordingCommand<OptionDefinition>(
          name: 'build',
          description: 'Build the app',
          trace: trace,
          middlewares: [
            Middlewares.onFinally((final _) async {
              trace.add('onFinally-start');
              await Future<void>.delayed(Duration.zero);
              throw StateError('onFinally');
            }),
          ],
        );
        final runner = CommandRunner<OptionDefinition, String>(
          'tool',
          'Tools',
          subcommands: [command],
        );
        result = await runner.run(['build']);
      });

      test(
        'when the command runs then the callback runs after the command',
        () {
          expect(trace, ['build', 'onFinally-start']);
        },
      );

      test('when the command runs then the command result is returned', () {
        expect(result, 'build');
      });
    },
  );

  group(
    'Given Middlewares.onFinally with a synchronous callback that throws '
    'on a failing command',
    () {
      late List<String> trace;
      late Object? error;

      setUp(() async {
        trace = [];
        error = null;
        final command = RecordingCommand<OptionDefinition>(
          name: 'build',
          description: 'Build the app',
          trace: trace,
          body: (final _) => throw StateError('boom'),
          middlewares: [
            Middlewares.onFinally((final _) {
              trace.add('onFinally');
              throw StateError('onFinally');
            }),
          ],
        );
        final runner = CommandRunner<OptionDefinition, String>(
          'tool',
          'Tools',
          subcommands: [command],
        );
        try {
          await runner.run(['build']);
        } on StateError catch (thrown) {
          error = thrown;
        }
      });

      test(
        'when the command fails then the callback runs after the command',
        () {
          expect(trace, ['build', 'onFinally']);
        },
      );

      test('when the command fails then the command exception propagates', () {
        expect(
          error,
          isA<StateError>().having(
            (final error) => error.message,
            'message',
            'boom',
          ),
        );
      });
    },
  );

  group(
    'Given Middlewares.onFinally with an asynchronous callback that throws '
    'on a failing command',
    () {
      late List<String> trace;
      late Object? error;

      setUp(() async {
        trace = [];
        error = null;
        final command = RecordingCommand<OptionDefinition>(
          name: 'build',
          description: 'Build the app',
          trace: trace,
          body: (final _) => throw StateError('boom'),
          middlewares: [
            Middlewares.onFinally((final _) async {
              trace.add('onFinally-start');
              await Future<void>.delayed(Duration.zero);
              throw StateError('onFinally');
            }),
          ],
        );
        final runner = CommandRunner<OptionDefinition, String>(
          'tool',
          'Tools',
          subcommands: [command],
        );
        try {
          await runner.run(['build']);
        } on StateError catch (thrown) {
          error = thrown;
        }
      });

      test(
        'when the command fails then the callback runs after the command',
        () {
          expect(trace, ['build', 'onFinally-start']);
        },
      );

      test('when the command fails then the command exception propagates', () {
        expect(
          error,
          isA<StateError>().having(
            (final error) => error.message,
            'message',
            'boom',
          ),
        );
      });
    },
  );

  group('Given Middlewares.withHooks with synchronous callbacks', () {
    const marker = StringOption(argName: 'marker');

    late List<String> trace;
    late String? seen;
    late String? result;

    setUp(() async {
      trace = [];
      seen = null;
      final command = RecordingCommand<OptionDefinition>(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        middlewares: [
          Middlewares.withHooks(
            onRun: (final context) {
              trace.add('onRun');
              return context.copyWith(
                config: Configuration.fromValues(
                  values: {marker: 'from-hook'},
                ),
              );
            },
            onReturn: (final _, final response) {
              trace.add('onReturn');
              return 'hook:$response';
            },
          ),
        ],
        body: (final context) {
          seen = context.config.optionalValue(marker);
          return 'build';
        },
      );
      final runner = CommandRunner<OptionDefinition, String>(
        'tool',
        'Tools',
        subcommands: [command],
      );
      result = await runner.run(['build']);
    });

    test('when the command runs then the hooks run around the command', () {
      expect(trace, ['onRun', 'build', 'onReturn']);
    });

    test(
      'when the command runs '
      'then the command receives the context from onRun',
      () {
        expect(seen, 'from-hook');
      },
    );

    test('when the command runs then the onReturn value is returned', () {
      expect(result, 'hook:build');
    });
  });

  group('Given Middlewares.withHooks with asynchronous callbacks', () {
    const marker = StringOption(argName: 'marker');

    late List<String> trace;
    late String? seen;
    late String? result;

    setUp(() async {
      trace = [];
      seen = null;
      final command = RecordingCommand<OptionDefinition>(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        middlewares: [
          Middlewares.withHooks(
            onRun: (final context) async {
              await Future<void>.delayed(Duration.zero);
              trace.add('onRun');
              return context.copyWith(
                config: Configuration.fromValues(
                  values: {marker: 'from-hook'},
                ),
              );
            },
            onReturn: (final _, final response) async {
              trace.add('onReturn-start');
              await Future<void>.delayed(Duration.zero);
              trace.add('onReturn-end');
              return 'hook:$response';
            },
          ),
        ],
        body: (final context) {
          seen = context.config.optionalValue(marker);
          return 'build';
        },
      );
      final runner = CommandRunner<OptionDefinition, String>(
        'tool',
        'Tools',
        subcommands: [command],
      );
      result = await runner.run(['build']);
    });

    test(
      'when the command runs then each hook finishes around the command',
      () {
        expect(trace, [
          'onRun',
          'build',
          'onReturn-start',
          'onReturn-end',
        ]);
      },
    );

    test(
      'when the command runs '
      'then the command receives the context from onRun',
      () {
        expect(seen, 'from-hook');
      },
    );

    test('when the command runs then the onReturn value is returned', () {
      expect(result, 'hook:build');
    });
  });

  group(
    'Given Middlewares.withHooks with a synchronous onError callback',
    () {
      late List<String> trace;
      late String? result;

      setUp(() async {
        trace = [];
        final command = RecordingCommand<OptionDefinition>(
          name: 'build',
          description: 'Build the app',
          trace: trace,
          body: (final _) => throw StateError('boom'),
          middlewares: [
            Middlewares.withHooks(
              onError: (final error, final _, final _) {
                trace.add('onError');
                return 'recovered:${(error as StateError).message}';
              },
            ),
          ],
        );
        final runner = CommandRunner<OptionDefinition, String>(
          'tool',
          'Tools',
          subcommands: [command],
        );
        result = await runner.run(['build']);
      });

      test(
        'when the command fails then the callback runs after the command',
        () {
          expect(trace, ['build', 'onError']);
        },
      );

      test('when the command fails then the callback value is returned', () {
        expect(result, 'recovered:boom');
      });
    },
  );

  group(
    'Given Middlewares.withHooks with an asynchronous onError callback',
    () {
      late List<String> trace;
      late String? result;

      setUp(() async {
        trace = [];
        final command = RecordingCommand<OptionDefinition>(
          name: 'build',
          description: 'Build the app',
          trace: trace,
          body: (final _) => throw StateError('boom'),
          middlewares: [
            Middlewares.withHooks(
              onError: (final error, final _, final _) async {
                trace.add('onError-start');
                await Future<void>.delayed(Duration.zero);
                trace.add('onError-end');
                return 'recovered:${(error as StateError).message}';
              },
            ),
          ],
        );
        final runner = CommandRunner<OptionDefinition, String>(
          'tool',
          'Tools',
          subcommands: [command],
        );
        result = await runner.run(['build']);
      });

      test(
        'when the command fails '
        'then the callback finishes after the command',
        () {
          expect(trace, ['build', 'onError-start', 'onError-end']);
        },
      );

      test('when the command fails then the callback value is returned', () {
        expect(result, 'recovered:boom');
      });
    },
  );

  group(
    'Given Middlewares.withHooks with a synchronous onFinally callback',
    () {
      late List<String> trace;
      late String? result;

      setUp(() async {
        trace = [];
        final command = RecordingCommand<OptionDefinition>(
          name: 'build',
          description: 'Build the app',
          trace: trace,
          middlewares: [
            Middlewares.withHooks(
              onReturn: (final _, final response) {
                trace.add('onReturn');
                return 'hook:$response';
              },
              onFinally: (final _) {
                trace.add('onFinally');
              },
            ),
          ],
        );
        final runner = CommandRunner<OptionDefinition, String>(
          'tool',
          'Tools',
          subcommands: [command],
        );
        result = await runner.run(['build']);
      });

      test(
        'when the command runs then onFinally runs after onReturn',
        () {
          expect(trace, ['build', 'onReturn', 'onFinally']);
        },
      );

      test('when the command runs then the onReturn value is returned', () {
        expect(result, 'hook:build');
      });
    },
  );

  group(
    'Given Middlewares.withHooks with an asynchronous onFinally callback',
    () {
      late List<String> trace;
      late String? result;

      setUp(() async {
        trace = [];
        final command = RecordingCommand<OptionDefinition>(
          name: 'build',
          description: 'Build the app',
          trace: trace,
          middlewares: [
            Middlewares.withHooks(
              onReturn: (final _, final response) async {
                trace.add('onReturn-start');
                await Future<void>.delayed(Duration.zero);
                trace.add('onReturn-end');
                return 'hook:$response';
              },
              onFinally: (final _) async {
                trace.add('onFinally-start');
                await Future<void>.delayed(Duration.zero);
                trace.add('onFinally-end');
              },
            ),
          ],
        );
        final runner = CommandRunner<OptionDefinition, String>(
          'tool',
          'Tools',
          subcommands: [command],
        );
        result = await runner.run(['build']);
      });

      test(
        'when the command runs then onFinally finishes after onReturn',
        () {
          expect(trace, [
            'build',
            'onReturn-start',
            'onReturn-end',
            'onFinally-start',
            'onFinally-end',
          ]);
        },
      );

      test('when the command runs then the onReturn value is returned', () {
        expect(result, 'hook:build');
      });
    },
  );

  group(
    'Given Middlewares.withHooks with synchronous onError and onFinally '
    'callbacks',
    () {
      late List<String> trace;
      late String? result;

      setUp(() async {
        trace = [];
        final command = RecordingCommand<OptionDefinition>(
          name: 'build',
          description: 'Build the app',
          trace: trace,
          body: (final _) => throw StateError('boom'),
          middlewares: [
            Middlewares.withHooks(
              onError: (final error, final _, final _) {
                trace.add('onError');
                return 'recovered:${(error as StateError).message}';
              },
              onFinally: (final _) {
                trace.add('onFinally');
              },
            ),
          ],
        );
        final runner = CommandRunner<OptionDefinition, String>(
          'tool',
          'Tools',
          subcommands: [command],
        );
        result = await runner.run(['build']);
      });

      test(
        'when the command fails then onFinally runs after onError',
        () {
          expect(trace, ['build', 'onError', 'onFinally']);
        },
      );

      test('when the command fails then the onError value is returned', () {
        expect(result, 'recovered:boom');
      });
    },
  );

  group(
    'Given Middlewares.withHooks with asynchronous onError and onFinally '
    'callbacks',
    () {
      late List<String> trace;
      late String? result;

      setUp(() async {
        trace = [];
        final command = RecordingCommand<OptionDefinition>(
          name: 'build',
          description: 'Build the app',
          trace: trace,
          body: (final _) => throw StateError('boom'),
          middlewares: [
            Middlewares.withHooks(
              onError: (final error, final _, final _) async {
                trace.add('onError-start');
                await Future<void>.delayed(Duration.zero);
                trace.add('onError-end');
                return 'recovered:${(error as StateError).message}';
              },
              onFinally: (final _) async {
                trace.add('onFinally-start');
                await Future<void>.delayed(Duration.zero);
                trace.add('onFinally-end');
              },
            ),
          ],
        );
        final runner = CommandRunner<OptionDefinition, String>(
          'tool',
          'Tools',
          subcommands: [command],
        );
        result = await runner.run(['build']);
      });

      test(
        'when the command fails then onFinally finishes after onError',
        () {
          expect(trace, [
            'build',
            'onError-start',
            'onError-end',
            'onFinally-start',
            'onFinally-end',
          ]);
        },
      );

      test('when the command fails then the onError value is returned', () {
        expect(result, 'recovered:boom');
      });
    },
  );

  group('Given an action option defined on the runner', () {
    late List<String> trace;
    late CommandRunner<OptionDefinition, String> runner;

    setUp(() {
      trace = [];
      runner = CommandRunner<OptionDefinition, String>(
        'tool',
        'Tools',
        globalOptions: [_VersionAction(trace)],
        middlewares: [_traceMiddleware(trace, 'root')],
        subcommands: [
          RecordingCommand<OptionDefinition>(
            name: 'project',
            description: 'Manage projects',
            trace: trace,
            middlewares: [_traceMiddleware(trace, 'project')],
          ),
        ],
      );
    });

    group('when --version precedes a subcommand', () {
      late String? result;

      setUp(() async {
        result = await runner.run(['--version', 'project']);
      });

      test(
        'then middleware runs through the runner '
        'and the subcommand does not run',
        () {
          expect(trace, [
            'root-before',
            'version',
            'root-after',
          ]);
        },
      );

      test('then the runner returns the wrapped action result', () {
        expect(result, 'root:version');
      });
    });
  });

  group('Given an action option defined on a branch command', () {
    late List<String> trace;
    late CommandRunner<OptionDefinition, String> runner;

    setUp(() {
      trace = [];
      final list = RecordingCommand<OptionDefinition>(
        name: 'list',
        description: 'List projects',
        trace: trace,
        middlewares: [_traceMiddleware(trace, 'list')],
      );
      final project = CommandImpl.branch<OptionDefinition, String>(
        name: 'project',
        description: 'Manage projects',
        persistentOptions: [_VersionAction(trace)],
        middlewares: [_traceMiddleware(trace, 'project')],
        subcommands: [list],
      );
      runner = CommandRunner<OptionDefinition, String>(
        'tool',
        'Tools',
        middlewares: [_traceMiddleware(trace, 'root')],
        subcommands: [project],
      );
    });

    group('when --version follows a nested subcommand', () {
      late String? result;

      setUp(() async {
        result = await runner.run(['project', 'list', '--version']);
      });

      test(
        'then middleware runs through the branch '
        'and the nested command does not run',
        () {
          expect(trace, [
            'root-before',
            'project-before',
            'version',
            'project-after',
            'root-after',
          ]);
        },
      );

      test('then the runner returns the wrapped action result', () {
        expect(result, 'root:project:version');
      });
    });
  });

  group('Given an action option enum that is itself the action', () {
    late List<String> trace;
    late CommandRunner<OptionDefinition, String> runner;

    setUp(() {
      trace = [];
      _enumActionTrace = trace;
      runner = CommandRunner<OptionDefinition, String>(
        'tool',
        'Tools',
        globalOptions: [_EnumVersionOption.version],
        subcommands: [
          RecordingCommand<OptionDefinition>(
            name: 'project',
            description: 'Manage projects',
            trace: trace,
          ),
        ],
      );
    });

    tearDown(() {
      _enumActionTrace = null;
    });

    group('when --version is passed', () {
      late String? result;

      setUp(() async {
        result = await runner.run(['--version', 'project']);
      });

      test('then that enum runs and the subcommand does not', () {
        expect(trace, ['enum-version']);
      });

      test('then the runner returns the enum action result', () {
        expect(result, 'enum-version');
      });
    });
  });

  group('Given an action option defined on a leaf command', () {
    late List<String> trace;
    late CommandRunner<OptionDefinition, String> runner;

    setUp(() {
      trace = [];
      final list = RecordingCommand<OptionDefinition>(
        name: 'list',
        description: 'List projects',
        trace: trace,
        options: [_VersionAction(trace)],
        middlewares: [_traceMiddleware(trace, 'list')],
      );
      final project = RecordingCommand<OptionDefinition>(
        name: 'project',
        description: 'Manage projects',
        trace: trace,
        middlewares: [_traceMiddleware(trace, 'project')],
        subcommands: [list],
      );
      runner = CommandRunner<OptionDefinition, String>(
        'tool',
        'Tools',
        middlewares: [_traceMiddleware(trace, 'root')],
        subcommands: [project],
      );
    });

    group('when --version is passed to that command', () {
      late String? result;

      setUp(() async {
        result = await runner.run(['project', 'list', '--version']);
      });

      test(
        'then middleware runs through the leaf '
        'and the leaf command does not run',
        () {
          expect(trace, [
            'root-before',
            'project-before',
            'list-before',
            'version',
            'list-after',
            'project-after',
            'root-after',
          ]);
        },
      );

      test('then the runner returns the wrapped action result', () {
        expect(result, 'root:project:list:version');
      });
    });
  });
}

CommandMiddleware<O, String> _traceMiddleware<O extends OptionDefinition>(
  final List<String> trace,
  final String label,
) {
  return (final next) => (final context) {
    trace.add('$label-before');
    final result = next(context);
    trace.add('$label-after');
    return '$label:$result';
  };
}

List<String>? _enumActionTrace;

enum _EnumVersionOption<V extends Object> with ActionOptionMixin<V> {
  version(FlagOption(argName: 'version', negatable: false));

  const _EnumVersionOption(this.option);

  @override
  final ConfigOptionBase<V> option;

  @override
  FutureOr<R?> run<O extends OptionDefinition, R>(
    final CommandContext<O, R> context,
  ) {
    _enumActionTrace?.add('enum-version');
    return 'enum-version' as R?;
  }
}

class _VersionAction extends FlagOption with ActionOptionMixin<bool> {
  _VersionAction(this.trace) : super(argName: 'version', negatable: false);

  final List<String> trace;

  @override
  FutureOr<R?> run<O extends OptionDefinition, R>(
    final CommandContext<O, R> context,
  ) {
    trace.add('version');
    return 'version' as R?;
  }
}

class _MarkerProvider implements ContextProvider {
  @override
  T fetch<T extends Object>() => throw ContextValueNotFound(T);

  @override
  T? maybeFetch<T extends Object>() => null;

  @override
  bool has<T extends Object>() => false;

  @override
  void store<T extends Object>(final T value) {}

  @override
  void remove<T extends Object>() {}
}
