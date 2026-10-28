import 'dart:async';

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
        usageOutput: usage.handler,
      );
    });

    group('when --help is passed', () {
      late String? result;

      setUp(() async {
        result = await runner.execute(['--help']);
      });

      test('then usage for the runner is printed to standard output', () {
        expect(usage.out.toString(), runner.usage);
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
        await runner.execute(['-h']);
      });

      test('then the same runner usage is printed to standard output', () {
        expect(usage.out.toString(), runner.usage);
        expect(usage.err.toString(), isEmpty);
      });
    });

    group('when the command line is the word help', () {
      late UsageException? error;

      setUp(() async {
        error = await _captureUsageError(() => runner.execute(['help']));
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
            runner.usage,
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
        usageOutput: usage.handler,
        subcommands: [_buildCommand(trace)],
      );
    });

    group('when --help is passed', () {
      setUp(() async {
        await runner.execute(['--help']);
      });

      test('then usage for the runner lists the command and help', () {
        expect(usage.out.toString(), runner.usage);
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
    late RecordingCommand build;
    late _CapturedUsage usage;

    setUp(() {
      trace = [];
      usage = _CapturedUsage();
      build = _buildCommand(trace);
      runner = TracingRunner(
        trace,
        usageOutput: usage.handler,
        subcommands: [build],
      );
    });

    group('when --help is passed', () {
      setUp(() async {
        await runner.execute(['--help']);
      });

      test(
        'then usage for the runner is printed to standard output',
        () {
          expect(usage.out.toString(), runner.usage);
          expect(usage.err.toString(), isEmpty);
        },
      );

      test('then no command runs', () {
        expect(trace, isEmpty);
      });
    });

    group('when --help precedes the build command', () {
      setUp(() async {
        await runner.execute(['--help', 'build']);
      });

      test(
        'then usage for the build command is printed to standard output',
        () {
          expect(usage.out.toString(), build.usage);
          expect(usage.err.toString(), isEmpty);
        },
      );

      test('then the build command does not run', () {
        expect(trace, isEmpty);
      });
    });

    group('when --help follows the build command', () {
      setUp(() async {
        await runner.execute(['build', '--help']);
      });

      test(
        'then usage for the build command is printed to standard output',
        () {
          expect(usage.out.toString(), build.usage);
          expect(usage.err.toString(), isEmpty);
        },
      );

      test('then the build command does not run', () {
        expect(trace, isEmpty);
      });
    });

    group('when help is asked for the build command', () {
      setUp(() async {
        await runner.execute(['help', 'build']);
      });

      test(
        'then usage for the build command is printed to standard output',
        () {
          expect(usage.out.toString(), build.usage);
          expect(usage.err.toString(), isEmpty);
        },
      );

      test('then the build command does not run', () {
        expect(trace, isEmpty);
      });
    });

    group('when the command line is the word help', () {
      setUp(() async {
        await runner.execute(['help']);
      });

      test(
        'then usage for the runner is printed to standard output',
        () {
          expect(usage.out.toString(), runner.usage);
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
    late RecordingCommand remote;
    late _CapturedUsage usage;

    setUp(() {
      trace = [];
      usage = _CapturedUsage();
      remote = _remoteCommand(trace);
      runner = TracingRunner(
        trace,
        usageOutput: usage.handler,
        subcommands: [remote],
      );
    });

    group('when help is asked for the branch', () {
      late UsageException? error;

      setUp(() async {
        error = await _captureUsageError(
          () => runner.execute(['help', 'remote']),
        );
      });

      test('then the missing subcommand is not an error', () {
        expect(error, isNull);
      });

      test(
        'then usage for the remote command is printed to standard output',
        () {
          expect(usage.out.toString(), remote.usage);
          expect(usage.err.toString(), isEmpty);
        },
      );

      test('then the branch command does not run', () {
        expect(trace, isEmpty);
      });
    });

    group('when help is asked for the nested command', () {
      setUp(() async {
        await runner.execute(['help', 'remote', 'add']);
      });

      test(
        'then usage for the nested command is printed to standard output',
        () {
          final add = remote.subcommands.firstWhere(
            (final command) => command.name == 'add',
          );
          expect(usage.out.toString(), add.usage);
          expect(usage.err.toString(), isEmpty);
        },
      );

      test('then the nested command does not run', () {
        expect(trace, isEmpty);
      });
    });

    group('when help is asked for an unknown nested command', () {
      late UsageException? error;

      setUp(() async {
        error = await _captureUsageError(
          () => runner.execute(['help', 'remote', 'bogus']),
        );
      });

      test('then the unknown subcommand is reported '
          'along with the remote usage', () {
        expect(error?.message, 'remote: Unknown subcommand: bogus.');
        expect(
          usage.err.toString(),
          _errorThenUsage('remote: Unknown subcommand: bogus.', remote.usage),
        );
        expect(usage.out.toString(), isEmpty);
      });
    });

    group('when help is the last command', () {
      setUp(() async {
        await runner.execute(['remote', 'help']);
      });

      test(
        'then usage for the remote command is printed to standard output',
        () {
          expect(usage.out.toString(), remote.usage);
          expect(usage.err.toString(), isEmpty);
        },
      );

      test('then the branch command does not run', () {
        expect(trace, isEmpty);
      });
    });
  });

  group('Given a command with mandatory options', () {
    late List<String> trace;
    late TracingRunner runner;
    late RecordingCommand deploy;
    late _CapturedUsage usage;

    setUp(() {
      trace = [];
      usage = _CapturedUsage();
      deploy = RecordingCommand(
        name: 'deploy',
        description: 'Deploy the app',
        trace: trace,
        options: const [
          StringOption(argName: 'target', argPos: 0, mandatory: true),
          FlagOption(argName: 'json', group: _format, negatable: false),
          FlagOption(argName: 'yaml', group: _format, negatable: false),
        ],
      );
      runner = TracingRunner(
        trace,
        usageOutput: usage.handler,
        subcommands: [deploy],
      );
    });

    group('when help is asked for the command', () {
      late UsageException? error;

      setUp(() async {
        error = await _captureUsageError(
          () => runner.execute(['help', 'deploy']),
        );
      });

      test('then the missing mandatory option and mandatory group '
          'are not errors', () {
        expect(error, isNull);
      });

      test('then usage for the command is printed to standard output', () {
        expect(usage.out.toString(), deploy.usage);
        expect(usage.err.toString(), isEmpty);
      });

      test('then the command does not run', () {
        expect(trace, isEmpty);
      });
    });

    group('when help is asked for the command with an invalid value', () {
      late UsageException? error;

      setUp(() async {
        error = await _captureUsageError(
          () => runner.execute(['help', 'deploy', '--json', '--yaml']),
        );
      });

      test('then usage is still printed without an error', () {
        expect(error, isNull);
        expect(usage.out.toString(), deploy.usage);
        expect(usage.err.toString(), isEmpty);
      });
    });

    group('when help is asked for the command with an unknown option', () {
      late UsageException? error;

      setUp(() async {
        error = await _captureUsageError(
          () => runner.execute(['help', 'deploy', '--bogus']),
        );
      });

      test('then the unknown option is reported along with the usage', () {
        expect(error?.message, 'deploy: Unknown option: --bogus.');
        expect(
          usage.err.toString(),
          _errorThenUsage('deploy: Unknown option: --bogus.', deploy.usage),
        );
        expect(usage.out.toString(), isEmpty);
      });
    });

    group('when the command is run without its mandatory options', () {
      late UsageException? error;

      setUp(() async {
        error = await _captureUsageError(() => runner.execute(['deploy']));
      });

      test('then the usage error is still reported', () {
        expect(error?.message, contains('mandatory'));
        expect(trace, isEmpty);
      });
    });
  });

  group('Given a runner with a mandatory global option', () {
    late List<String> trace;
    late TracingRunner runner;
    late _CapturedUsage usage;

    setUp(() {
      trace = [];
      usage = _CapturedUsage();
      runner = TracingRunner(
        trace,
        usageOutput: usage.handler,
        globalOptions: const [
          StringOption(argName: 'account', mandatory: true),
          CommandRunnerBuiltinOptions.help,
        ],
        subcommands: [_buildCommand(trace)],
      );
    });

    test('when the command line is the word help '
        'then usage for the runner is printed without an error', () async {
      final error = await _captureUsageError(() => runner.execute(['help']));
      expect(error, isNull);
      expect(usage.out.toString(), runner.usage);
      expect(usage.err.toString(), isEmpty);
    });

    test('when help is asked for the build command '
        'then its usage is printed without an error', () async {
      final error = await _captureUsageError(
        () => runner.execute(['help', 'build']),
      );
      expect(error, isNull);
      expect(usage.out.toString(), contains('Usage: tool build'));
      expect(usage.err.toString(), isEmpty);
    });

    test('when the runner has an unknown option before help '
        'then the unknown option is reported', () async {
      final error = await _captureUsageError(
        () => runner.execute(['--bogus', 'help']),
      );
      expect(error?.message, 'tool: Unknown option: --bogus.');
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
        usageOutput: usage.handler,
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
      setUp(() async {
        await runner.execute(['--help', 'help']);
      });

      test(
        'then usage for the help command is printed to standard output',
        () {
          expect(usage.out.toString(), _helpCommand(runner).usage);
          expect(usage.err.toString(), isEmpty);
        },
      );

      test('then no command runs', () {
        expect(trace, isEmpty);
      });
    });

    group('when help is asked for the hidden command', () {
      late UsageException? error;

      setUp(() async {
        error = await _captureUsageError(
          () => runner.execute(['help', 'secret']),
        );
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
              _helpCommand(runner).usage,
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
        await runner.execute(['help']);

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
        result = await runner.execute(['help']);
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
    late _CapturedUsage usage;
    late CommandRunner<OptionDefinition, String> runner;

    setUp(() async {
      trace = [];
      usage = _CapturedUsage();
      runner = CommandRunner<OptionDefinition, String>(
        'tool',
        'Tools',
        usageOutput: usage.handler,
        middlewares: [
          (final next) => (final context) {
            trace.add('root');
            return next(context);
          },
        ],
        subcommands: [_buildCommand(trace)],
      );
      await runner.execute(['--help']);
    });

    test(
      'when --help is passed '
      'then usage for the runner is printed to standard output',
      () {
        expect(usage.out.toString(), runner.usage);
        expect(usage.err.toString(), isEmpty);
      },
    );

    test('when --help is passed then middleware does not run', () {
      expect(trace, isEmpty);
    });
  });
}

const _format = MutuallyExclusive(
  'Format',
  mode: MutuallyExclusiveMode.mandatory,
);

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

/// Buffers passed to [UsageOutputHandler] so tests can read usage text.
class _CapturedUsage {
  final out = StringBuffer();
  final err = StringBuffer();

  late final UsageOutputHandler handler = UsageOutputHandler(
    sinks: UsageSinks(out: out, err: err),
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
  _GuideCommand(this.trace);

  final List<String> trace;

  @override
  String? run(final CommandContext context) {
    trace.add('guide');
    return 'guided';
  }
}

CommandDefinition _helpCommand(final CommandDefinition command) =>
    command.subcommands.firstWhere((final sub) => sub.name == 'help');

String _errorThenUsage(final String message, final String usage) =>
    '$message\n\n$usage';
