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

      setUp(() async {
        error = await _captureUsageError(() => runner.run([]));
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
        result = await runner.run(['build']);
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

      setUp(() async {
        error = await _captureUsageError(() => runner.run(['missing']));
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

      setUp(() async {
        error = await _captureUsageError(
          () => runner.run(['build', '--missing']),
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

      setUp(() async {
        error = await _captureUsageError(
          () => runner.run(['build', 'extra']),
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
        result = await runner.run([]);
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
        result = await runner.run(['build']);
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
        await runner.run(['build', 'extra']);

        expect(trace, ['build']);
      },
    );
  });

  group('Given a command created with a run function', () {
    test(
      'when the runner invokes it '
      'then that function result is returned',
      () async {
        final command = CommandImpl.leafWithRunFunction(
          name: 'build',
          description: 'Build the app',
          run: (final context) => 'from-function',
        );
        final runner = CommandRunner(
          'tool',
          'Tools',
          subcommands: [command],
        );

        expect(await runner.run(['build']), 'from-function');
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
        await runner.run(['build']);

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
      await runner.run(['b']);

      expect(trace, ['build']);
    });

    group('when a suggestion alias is used', () {
      late UsageException? error;

      setUp(() async {
        error = await _captureUsageError(() => runner.run(['bld']));
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
      await runner.run(['secret']);

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

      setUp(() async {
        error = await _captureUsageError(() => runner.run(['build']));
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
        result = await runner.run(['build', 'check']);
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

        await added.run(['remote', 'add']);

        expect(addedTrace, ['add']);
      },
    );
  });

  group('Given a branch defined by parameters that can run as a leaf', () {
    late List<String> trace;
    late StringBuffer usageOut;
    late Command<OptionDefinition, String> remote;
    late TracingRunner runner;

    setUp(() {
      trace = [];
      usageOut = StringBuffer();
      remote = CommandImpl.branch(
        name: 'remote',
        description: 'Manage remotes',
        canRunAsLeafCommand: true,
        subcommands: [
          RecordingCommand(
            name: 'add',
            description: 'Add a remote',
            trace: trace,
          ),
        ],
      );
      runner = TracingRunner(
        trace,
        usageOutput: UsageOutputHandler(
          sinks: OutputSinks(out: usageOut, err: StringBuffer()),
        ),
        subcommands: [remote],
      );
    });

    group('when the branch command is the last command', () {
      late String? result;

      setUp(() async {
        result = await runner.run(['remote']);
      });

      test('then usage for the branch command is printed', () {
        expect(usageOut.toString(), remote.usage);
      });

      test('then no result is returned', () {
        expect(result, isNull);
      });

      test('then no command runs', () {
        expect(trace, isEmpty);
      });
    });

    group('when the nested command line is run', () {
      late String? result;

      setUp(() async {
        result = await runner.run(['remote', 'add']);
      });

      test('then only the nested command runs', () {
        expect(trace, ['add']);
      });

      test('then the nested command result is returned', () {
        expect(result, 'add');
      });

      test('then no usage is printed', () {
        expect(usageOut.toString(), isEmpty);
      });
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
        expect(await runner.run(['build']), 'later');
      },
    );
  });
}

Future<UsageException?> _captureUsageError(
  final FutureOr<Object?> Function() body,
) async {
  try {
    await body();
  } on UsageException catch (error) {
    return error;
  }
  return null;
}
