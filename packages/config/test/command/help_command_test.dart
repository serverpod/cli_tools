import 'package:config/command.dart';
import 'package:config/config.dart';
import 'package:test/test.dart';

import 'command_fixtures.dart';

void main() {
  group('Given a runner with no subcommands', () {
    late List<String> trace;
    late TracingRunner runner;
    late _CapturedUsage usage;

    setUp(() {
      trace = [];
      usage = _CapturedUsage();
      runner = TracingRunner(
        trace,
        usageOutputSettings: usage.settings,
      );
    });

    group('when --help is passed', () {
      late String? result;

      setUp(() async {
        result = await runner.runner(['--help']);
      });

      test('then usage for the runner is printed to standard output', () {
        expect(usage.out.toString(), _runnerUsage);
        expect(usage.err.toString(), isEmpty);
      });

      test('then no command runs', () {
        expect(trace, isEmpty);
      });

      test('then no command result is returned', () {
        expect(result, isNull);
      });
    });

    group('when -h is passed', () {
      setUp(() async {
        await runner.runner(['-h']);
      });

      test('then the same runner usage is printed to standard output', () {
        expect(usage.out.toString(), _runnerUsage);
        expect(usage.err.toString(), isEmpty);
      });
    });

    group('when the command line is the word help', () {
      late UsageException? error;

      setUp(() {
        error = _captureUsageError(() => runner.runner(['help']));
      });

      test('then the unexpected word is reported', () {
        expect(
          error?.message,
          "tool: Unexpected positional argument(s): 'help'",
        );
      });

      test('then the error and runner usage are printed to standard error', () {
        expect(
          usage.err.toString(),
          _errorThenUsage(
            "tool: Unexpected positional argument(s): 'help'",
            _runnerUsage,
          ),
        );
        expect(usage.out.toString(), isEmpty);
      });
    });
  });

  group('Given a runner that can run as a leaf', () {
    late List<String> trace;
    late TracingRunner runner;
    late _CapturedUsage usage;

    setUp(() {
      trace = [];
      usage = _CapturedUsage();
      runner = TracingRunner(
        trace,
        canRunAsLeafCommand: true,
        usageOutputSettings: usage.settings,
        subcommands: [_buildCommand(trace)],
      );
    });

    group('when --help is passed', () {
      setUp(() async {
        await runner.runner(['--help']);
      });

      test('then usage for the runner lists the command and help', () {
        expect(usage.out.toString(), _runnerWithBuildUsage);
        expect(usage.err.toString(), isEmpty);
      });

      test('then no command runs', () {
        expect(trace, isEmpty);
      });
    });
  });

  group('Given a runner with a build command', () {
    late List<String> trace;
    late TracingRunner runner;
    late _CapturedUsage usage;

    setUp(() {
      trace = [];
      usage = _CapturedUsage();
      runner = TracingRunner(
        trace,
        usageOutputSettings: usage.settings,
        subcommands: [_buildCommand(trace)],
      );
    });

    group('when --help is passed', () {
      late UsageException? error;

      setUp(() {
        error = _captureUsageError(() => runner.runner(['--help']));
      });

      test('then a subcommand is required', () {
        expect(error?.message, 'tool: A subcommand is required under tool.');
      });

      test('then the error and runner usage are printed to standard error', () {
        expect(
          usage.err.toString(),
          _errorThenUsage(
            'tool: A subcommand is required under tool.',
            _runnerWithBuildUsage,
          ),
        );
        expect(usage.out.toString(), isEmpty);
      });

      test('then no command runs', () {
        expect(trace, isEmpty);
      });
    });

    group('when --help precedes the build command', () {
      setUp(() async {
        await runner.runner(['--help', 'build']);
      });

      test(
        'then usage for the build command is printed to standard output',
        () {
          expect(usage.out.toString(), _buildUsage);
          expect(usage.err.toString(), isEmpty);
        },
      );

      test('then the build command does not run', () {
        expect(trace, isEmpty);
      });
    });

    group('when --help follows the build command', () {
      setUp(() async {
        await runner.runner(['build', '--help']);
      });

      test(
        'then usage for the build command is printed to standard output',
        () {
          expect(usage.out.toString(), _buildUsage);
          expect(usage.err.toString(), isEmpty);
        },
      );

      test('then the build command does not run', () {
        expect(trace, isEmpty);
      });
    });

    group('when help is asked for the build command', () {
      setUp(() async {
        await runner.runner(['help', 'build']);
      });

      test(
        'then usage for the build command is printed to standard output',
        () {
          expect(usage.out.toString(), _buildUsage);
          expect(usage.err.toString(), isEmpty);
        },
      );

      test('then the build command does not run', () {
        expect(trace, isEmpty);
      });
    });
  });

  group('Given a branch command', () {
    late List<String> trace;
    late TracingRunner runner;
    late _CapturedUsage usage;

    setUp(() {
      trace = [];
      usage = _CapturedUsage();
      runner = TracingRunner(
        trace,
        usageOutputSettings: usage.settings,
        subcommands: [_remoteCommand(trace)],
      );
    });

    group('when help is asked for the branch', () {
      late UsageException? error;

      setUp(() {
        error = _captureUsageError(
          () => runner.runner(['help', 'remote']),
        );
      });

      test('then a subcommand is required', () {
        expect(
          error?.message,
          'remote: A subcommand is required under remote.',
        );
      });

      test(
        'then the error and remote usage are printed to standard error',
        () {
          expect(
            usage.err.toString(),
            _errorThenUsage(
              'remote: A subcommand is required under remote.',
              _remoteUsage,
            ),
          );
          expect(usage.out.toString(), isEmpty);
        },
      );

      test('then the branch command does not run', () {
        expect(trace, isEmpty);
      });
    });

    group('when help is the last command', () {
      late UsageException? error;

      setUp(() {
        error = _captureUsageError(
          () => runner.runner(['remote', 'help']),
        );
      });

      test('then a subcommand is required', () {
        expect(error?.message, 'help: A subcommand is required under help.');
      });

      test(
        'then the error and help usage are printed to standard error',
        () {
          expect(
            usage.err.toString(),
            _errorThenUsage(
              'help: A subcommand is required under help.',
              _helpForRemoteUsage,
            ),
          );
          expect(usage.out.toString(), isEmpty);
        },
      );

      test('then the branch command does not run', () {
        expect(trace, isEmpty);
      });
    });
  });

  group('Given a visible command and a hidden command', () {
    late List<String> trace;
    late TracingRunner runner;
    late _CapturedUsage usage;

    setUp(() {
      trace = [];
      usage = _CapturedUsage();
      runner = TracingRunner(
        trace,
        usageOutputSettings: usage.settings,
        subcommands: [
          _buildCommand(trace),
          RecordingCommand(
            name: 'secret',
            description: 'Hidden command',
            trace: trace,
            hidden: true,
          ),
        ],
      );
    });

    group('when help describes itself', () {
      late UsageException? error;

      setUp(() {
        error = _captureUsageError(
          () => runner.runner(['--help', 'help']),
        );
      });

      test('then a subcommand is required', () {
        expect(error?.message, 'help: A subcommand is required under help.');
      });

      test(
        'then the error and help usage are printed to standard error',
        () {
          expect(
            usage.err.toString(),
            _errorThenUsage(
              'help: A subcommand is required under help.',
              _helpForRunnerUsage,
            ),
          );
          expect(usage.out.toString(), isEmpty);
        },
      );
    });

    group('when help is asked for the hidden command', () {
      late UsageException? error;

      setUp(() {
        error = _captureUsageError(() => runner.runner(['help', 'secret']));
      });

      test('then a usage exception is thrown', () {
        expect(error, isA<UsageException>());
      });

      test(
        'then the error and help usage are printed to standard error',
        () {
          expect(
            usage.err.toString(),
            _errorThenUsage(
              'help: Unknown subcommand: secret.',
              _helpForRunnerUsage,
            ),
          );
          expect(usage.out.toString(), isEmpty);
        },
      );
    });
  });

  group('Given a custom command named help', () {
    late List<String> trace;
    late TracingRunner runner;

    setUp(() {
      trace = [];
      final help = RecordingCommand(
        name: 'help',
        description: 'Custom help',
        trace: trace,
      );
      final build = RecordingCommand(
        name: 'build',
        description: 'Build the app',
        trace: trace,
      );
      runner = TracingRunner(trace, subcommands: [build, help]);
    });

    test(
      'when help is invoked '
      'then only the custom command runs',
      () async {
        await runner.runner(['help']);

        expect(trace, ['help']);
      },
    );
  });

  group('Given a help command with a custom run method', () {
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
          ),
          _GuideCommand(trace),
        ],
      );
    });

    group('when help is invoked', () {
      late String? result;

      setUp(() async {
        result = await runner.runner(['help']);
      });

      test('then only the custom help command runs', () {
        expect(trace, ['guide']);
      });

      test('then its result is returned', () {
        expect(result, 'guided');
      });
    });
  });

  group('Given runner middleware and a help request', () {
    late List<String> trace;
    late UsageException? error;
    late _CapturedUsage usage;

    setUp(() {
      trace = [];
      usage = _CapturedUsage();
      error = null;
      final runner = CommandRunner<OptionDefinition, String>(
        'tool',
        'Tools',
        usageOutputSettings: usage.settings,
        middlewares: [
          (final next) => (final context) {
            trace.add('root');
            return next(context);
          },
        ],
        subcommands: [_buildCommand(trace)],
      );
      error = _captureUsageError(() => runner.runner(['--help']));
    });

    test('when --help is passed then a subcommand is required', () {
      expect(error?.message, 'tool: A subcommand is required under tool.');
    });

    test('when --help is passed then middleware does not run', () {
      expect(trace, isEmpty);
    });

    test(
      'when --help is passed '
      'then the error and runner usage are printed to standard error',
      () {
        expect(
          usage.err.toString(),
          _errorThenUsage(
            'tool: A subcommand is required under tool.',
            _runnerWithBuildUsage,
          ),
        );
        expect(usage.out.toString(), isEmpty);
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

/// Buffers passed to [UsageOutputSettings] so tests can read usage text.
class _CapturedUsage {
  final out = StringBuffer();
  final err = StringBuffer();

  late final UsageOutputSettings settings = UsageOutputSettings(
    out: out,
    err: err,
  );
}

RecordingCommand _buildCommand(final List<String> trace) {
  return RecordingCommand(
    name: 'build',
    description: 'Build the app',
    trace: trace,
    aliases: ['b'],
    options: const [
      StringOption(argName: 'target', argAbbrev: 't'),
      FlagOption(argName: 'release', defaultsTo: false),
      StringOption(argPos: 0),
    ],
  );
}

RecordingCommand _remoteCommand(final List<String> trace) {
  return RecordingCommand(
    name: 'remote',
    description: 'Manage remotes',
    trace: trace,
    aliases: ['r'],
    options: const [
      StringOption(argName: 'env', argAbbrev: 'e'),
    ],
    subcommands: [
      RecordingCommand(
        name: 'add',
        description: 'Add a remote',
        trace: trace,
      ),
    ],
  );
}

class _GuideCommand extends HelpCommand<String> {
  _GuideCommand(this.trace) : super(helpCommands: () => const []);

  final List<String> trace;

  @override
  String? run(final RunCommandContext runContext) {
    trace.add('guide');
    return 'guided';
  }
}

String _usage(final Iterable<String> lines) => '${lines.join('\n')}\n';

String _errorThenUsage(final String message, final String usage) =>
    '$message\n\n$usage';

final String _runnerUsage = _usage([
  'Command: tool',
  'Description: Tools',
]);

final String _runnerWithBuildUsage = _usage([
  'Command: tool',
  'Description: Tools',
  'Subcommands:',
  '  build',
  '  help',
]);

final String _buildUsage = _usage([
  'Command: build',
  'Description: Build the app',
  'Aliases: b',
  'Named options:',
  '  target / t',
  '  release',
  'Positional Options:',
  '  0',
]);

final String _remoteUsage = _usage([
  'Command: remote',
  'Description: Manage remotes',
  'Aliases: r',
  'Subcommands:',
  '  add',
  '  help',
  'Named options:',
  '  env / e',
]);

final String _helpForRemoteUsage = _usage([
  'Command: help',
  'Description: Show help for a command.',
  'Subcommands:',
  '  add',
]);

final String _helpForRunnerUsage = _usage([
  'Command: help',
  'Description: Show help for a command.',
  'Subcommands:',
  '  build',
]);
