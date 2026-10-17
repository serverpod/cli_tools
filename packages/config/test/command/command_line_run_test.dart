import 'dart:async';

import 'package:config/command.dart';
import 'package:config/config.dart';
import 'package:test/test.dart';

import 'command_fixtures.dart';

void main() {
  group('Given a runner with a build command', () {
    late List<String> trace;
    late TracingRunner runner;

    setUp(() {
      trace = [];
      runner = TracingRunner(
        trace,
        usageOutput: noUsageErrorOutput,
        subcommands: [
          RecordingCommand(
            name: 'build',
            description: 'Build the app',
            trace: trace,
          ),
        ],
      );
    });

    group('when the runner is started with no arguments', () {
      late UsageException? error;

      setUp(() {
        error = _captureUsageError(() => runner.runner([]));
      });

      test('then a subcommand is required', () {
        expect(error?.message, 'tool: A subcommand is required under tool.');
      });

      test('then no command runs', () {
        expect(trace, isEmpty);
      });
    });

    group('when the build command is invoked', () {
      late String? result;

      setUp(() async {
        result = await runner.runner(['build']);
      });

      test('then only the build command runs', () {
        expect(trace, ['build']);
      });

      test('then the build command result is returned', () {
        expect(result, 'build');
      });
    });

    group('when the command line names an unknown command', () {
      late UsageException? error;

      setUp(() {
        error = _captureUsageError(() => runner.runner(['missing']));
      });

      test('then the unknown command is reported', () {
        expect(error, isA<UsageException>());
        expect(error?.message, contains('missing'));
      });

      test('then no command runs', () {
        expect(trace, isEmpty);
      });
    });

    group('when the command line contains an unknown option', () {
      late UsageException? error;

      setUp(() {
        error = _captureUsageError(
          () => runner.runner(['build', '--missing']),
        );
      });

      test('then the unknown option is reported', () {
        expect(error?.message, 'build: Unknown option: --missing.');
      });

      test('then no command runs', () {
        expect(trace, isEmpty);
      });
    });

    group('when the leaf command receives an extra positional argument', () {
      late UsageException? error;

      setUp(() {
        error = _captureUsageError(
          () => runner.runner(['build', 'extra']),
        );
      });

      test('then the unexpected argument is reported', () {
        expect(
          error?.message,
          "build: Unexpected positional argument(s): 'extra'",
        );
      });

      test('then no command runs', () {
        expect(trace, isEmpty);
      });
    });
  });

  group('Given a runner that can run as a leaf', () {
    late List<String> trace;
    late TracingRunner runner;

    setUp(() {
      trace = [];
      runner = TracingRunner(
        trace,
        canRunAsLeafCommand: true,
        subcommands: [
          RecordingCommand(
            name: 'build',
            description: 'Build the app',
            trace: trace,
          ),
        ],
      );
    });

    group('when the runner is started with no arguments', () {
      late String? result;

      setUp(() async {
        result = await runner.runner([]);
      });

      test('then only the root command runs', () {
        expect(trace, ['tool']);
      });

      test('then the root result is returned', () {
        expect(result, 'tool');
      });
    });

    group('when the build command is invoked', () {
      late String? result;

      setUp(() async {
        result = await runner.runner(['build']);
      });

      test('then only the build command runs', () {
        expect(trace, ['build']);
      });

      test('then the build command result is returned', () {
        expect(result, 'build');
      });
    });
  });

  group('Given a runner that ignores unexpected positional arguments', () {
    late List<String> trace;
    late TracingRunner runner;

    setUp(() {
      trace = [];
      runner = TracingRunner(
        trace,
        ignoreUnexpectedPositionalArgs: true,
        subcommands: [
          RecordingCommand(
            name: 'build',
            description: 'Build the app',
            trace: trace,
          ),
        ],
      );
    });

    test(
      'when the leaf command receives an extra positional argument '
      'then the command runs',
      () async {
        await runner.runner(['build', 'extra']);

        expect(trace, ['build']);
      },
    );
  });

  group('Given a command created with a run function', () {
    test(
      'when the runner invokes it '
      'then that function result is returned',
      () async {
        final command = CommandImpl.withRunFunction(
          name: 'build',
          description: 'Build the app',
          run: (final context) => 'from-function',
        );
        final runner = CommandRunner(
          'tool',
          'Tools',
          subcommands: [command],
        );

        expect(await runner.runner(['build']), 'from-function');
      },
    );
  });

  group('Given a runner that gains its command after construction', () {
    late List<String> trace;
    late TracingRunner runner;

    setUp(() {
      trace = [];
      runner = TracingRunner(trace);
      runner.addSubcommand(
        RecordingCommand(
          name: 'build',
          description: 'Build the app',
          trace: trace,
        ),
      );
    });

    test(
      'when the added command is invoked '
      'then that command runs',
      () async {
        await runner.runner(['build']);

        expect(trace, ['build']);
      },
    );
  });

  group('Given a build command with an alias and a suggestion alias', () {
    late List<String> trace;
    late TracingRunner runner;

    setUp(() {
      trace = [];
      runner = TracingRunner(
        trace,
        usageOutput: noUsageErrorOutput,
        subcommands: [
          RecordingCommand(
            name: 'build',
            description: 'Build the app',
            trace: trace,
            aliases: ['b'],
            suggestionAliases: ['bld'],
          ),
        ],
      );
    });

    test('when the alias is used then the build command runs', () async {
      await runner.runner(['b']);

      expect(trace, ['build']);
    });

    group('when a suggestion alias is used', () {
      late UsageException? error;

      setUp(() {
        error = _captureUsageError(() => runner.runner(['bld']));
      });

      test('then a usage exception is thrown', () {
        expect(error, isA<UsageException>());
      });

      test('then the build command does not run', () {
        expect(trace, isEmpty);
      });
    });
  });

  group('Given a hidden command', () {
    late List<String> trace;
    late TracingRunner runner;

    setUp(() {
      trace = [];
      runner = TracingRunner(
        trace,
        subcommands: [
          RecordingCommand(
            name: 'secret',
            description: 'Hidden command',
            trace: trace,
            hidden: true,
          ),
        ],
      );
    });

    test('when the command is invoked by name then it runs', () async {
      await runner.runner(['secret']);

      expect(trace, ['secret']);
    });
  });

  group('Given a branch command with a nested command', () {
    late List<String> trace;
    late TracingRunner runner;

    setUp(() {
      trace = [];
      final child = RecordingCommand(
        name: 'check',
        description: 'Check the app',
        trace: trace,
      );
      final parent = RecordingCommand(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        subcommands: [child],
      );
      runner = TracingRunner(
        trace,
        usageOutput: noUsageErrorOutput,
        subcommands: [parent],
      );
    });

    group('when the branch command is the last command', () {
      late UsageException? error;

      setUp(() {
        error = _captureUsageError(() => runner.runner(['build']));
      });

      test('then a subcommand is required', () {
        expect(error?.message, 'build: A subcommand is required under build.');
      });

      test('then no command runs', () {
        expect(trace, isEmpty);
      });
    });

    group('when the nested command line is run', () {
      late String? result;

      setUp(() async {
        result = await runner.runner(['build', 'check']);
      });

      test('then only the leaf command runs', () {
        expect(trace, ['check']);
      });

      test('then the leaf result is returned', () {
        expect(result, 'check');
      });
    });

    group('when the branch command body throws', () {
      late String? result;

      setUp(() async {
        trace = [];
        final child = RecordingCommand(
          name: 'check',
          description: 'Check the app',
          trace: trace,
        );
        final parent = RecordingCommand(
          name: 'build',
          description: 'Build the app',
          trace: trace,
          subcommands: [child],
          body: (final context) => throw StateError('boom'),
        );
        final failingRunner = TracingRunner(trace, subcommands: [parent]);
        result = await failingRunner.runner(['build', 'check']);
      });

      test('then only the leaf command runs', () {
        expect(trace, ['check']);
      });

      test('then the leaf result is returned', () {
        expect(result, 'check');
      });
    });

    test(
      'when the nested command is added with addSubcommand '
      'then the leaf command runs',
      () async {
        final addedTrace = <String>[];
        final branch = RecordingCommand(
          name: 'remote',
          description: 'Manage remotes',
          trace: addedTrace,
        );
        final child = RecordingCommand(
          name: 'add',
          description: 'Add a remote',
          trace: addedTrace,
        );
        // ignore: deprecated_member_use_from_same_package
        branch.addSubcommand(child);
        final added = TracingRunner(addedTrace, subcommands: [branch]);

        await added.runner(['remote', 'add']);

        expect(addedTrace, ['add']);
      },
    );
  });

  group('Given a nested command that runs on its own', () {
    late List<String> trace;
    late TracingRunner runner;

    setUp(() {
      trace = [];
      final child = RecordingCommand(
        name: 'version',
        description: 'Show the version',
        trace: trace,
        standalone: true,
        body: (final context) => '1.0.0',
      );
      final parent = RecordingCommand(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        subcommands: [child],
      );
      runner = TracingRunner(trace, subcommands: [parent]);
    });

    group('when the standalone command is last on the command line', () {
      late String? result;

      setUp(() async {
        result = await runner.runner(['build', 'version']);
      });

      test('then ancestor commands do not run', () {
        expect(trace, ['version']);
      });

      test('then the standalone command result is returned', () {
        expect(result, '1.0.0');
      });
    });

    group('when the standalone command is missing a mandatory option', () {
      late UsageException? error;
      late StringBuffer err;

      setUp(() {
        trace = [];
        error = null;
        err = StringBuffer();
        final child = RecordingCommand<StringOption>(
          name: 'version',
          description: 'Show the version',
          trace: trace,
          standalone: true,
          options: const [
            StringOption(argName: 'name', mandatory: true),
          ],
          middlewares: [
            (final next) => (final context) {
              trace.add('middleware');
              return next(context);
            },
          ],
        );
        final parent = RecordingCommand(
          name: 'build',
          description: 'Build the app',
          trace: trace,
          options: const [
            StringOption(argName: 'target', mandatory: true),
          ],
          subcommands: [child],
        );
        final failingRunner = TracingRunner(
          trace,
          usageOutput: UsageOutputHandler(sinks: UsageSinks(err: err)),
          subcommands: [parent],
        );
        try {
          failingRunner.runner(['build', 'version']);
        } on UsageException catch (e) {
          error = e;
        }
      });

      test('then every configuration error is reported', () {
        expect(
          error?.message,
          'build: Option `target` is mandatory.\n'
          'version: Option `name` is mandatory.',
        );
      });

      test('then no command or middleware runs', () {
        expect(trace, isEmpty);
      });

      test(
        'then usage for the first command with errors is printed',
        () {
          expect(
            err.toString(),
            'build: Option `target` is mandatory.\n'
            'version: Option `name` is mandatory.\n'
            '\n'
            'Command: build\n'
            'Description: Build the app\n'
            'Subcommands:\n'
            '  version\n'
            '  help\n'
            'Named options:\n'
            '  target\n',
          );
        },
      );
    });
  });

  group('Given a command that completes asynchronously', () {
    late List<String> trace;
    late TracingRunner runner;

    setUp(() {
      trace = [];
      runner = TracingRunner(
        trace,
        subcommands: [
          RecordingCommand(
            name: 'build',
            description: 'Build the app',
            trace: trace,
            body: (final context) async {
              await Future<void>.delayed(Duration.zero);
              return 'later';
            },
          ),
        ],
      );
    });

    test(
      'when the command is invoked '
      'then its future result is returned',
      () async {
        expect(await runner.runner(['build']), 'later');
      },
    );
  });
}

UsageException? _captureUsageError(final void Function() body) {
  try {
    body();
  } on UsageException catch (error) {
    return error;
  }
  return null;
}
