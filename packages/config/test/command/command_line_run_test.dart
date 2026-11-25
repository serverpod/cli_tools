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

    group(
      'when an unrecognized subcommand is followed by an invalid option',
      () {
        late UsageException? error;

        setUp(() async {
          error = await _captureUsageError(
            () => runner.run(['wrong-subcommand', '--wrong-option']),
          );
        });

        test('then the subcommand error is shown before the option error', () {
          expect(
            error?.message,
            'tool: Unknown subcommand: "wrong-subcommand"\n'
            'tool: Unknown option: --wrong-option.',
          );
        });

        test('then no command runs', () {
          expect(trace, isEmpty);
        });
      },
    );

    group(
      'when an invalid option precedes an unrecognized subcommand',
      () {
        late UsageException? error;

        setUp(() async {
          error = await _captureUsageError(
            () => runner.run(['--wrong-option', 'wrong-subcommand']),
          );
        });

        test('then both errors are shown', () {
          expect(
            error?.message,
            'tool: Unknown option: --wrong-option.\n'
            'tool: Unknown subcommand: "wrong-subcommand"',
          );
        });

        test('then no command runs', () {
          expect(trace, isEmpty);
        });
      },
    );

    group(
      'when a misspelled subcommand is followed by an unknown short option',
      () {
        late UsageException? error;

        setUp(() async {
          error = await _captureUsageError(
            () => runner.run(['biuld', '-x']),
          );
        });

        test('then the subcommand error is shown before the option error', () {
          expect(
            error?.message,
            'tool: Unknown subcommand: "biuld" (Did you mean build?)\n'
            'tool: Unknown option: -x.',
          );
        });
      },
    );

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

  group('Given a build command that accepts an output option', () {
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
            options: const [
              StringOption(argName: 'output'),
            ],
          ),
        ],
      );
    });

    group(
      'when the subcommand is misspelled and that option is passed',
      () {
        late UsageException? error;

        setUp(() async {
          error = await _captureUsageError(
            () => runner.run(['biuld', '--output', 'app']),
          );
        });

        test(
          'then the subcommand error is shown before the option error',
          () {
            expect(
              error?.message,
              'tool: Unknown subcommand: "biuld" (Did you mean build?)\n'
              'tool: Unknown option: --output.\n'
              'tool: Unknown subcommand: "app"',
            );
          },
        );

        test('then no command runs', () {
          expect(trace, isEmpty);
        });
      },
    );
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

  group(
    'Given a leaf command that ignores unexpected positional arguments',
    () {
      late List<String> trace;
      late RecordingCommand<OptionDefinition> command;
      late TracingRunner runner;

      setUp(() {
        trace = [];
        command = RecordingCommand(
          name: 'build',
          description: 'Build the app',
          trace: trace,
          ignoreUnexpectedPositionalArgs: true,
        );
        runner = TracingRunner(
          trace,
          subcommands: [command],
        );
      });

      test('when reading the command then the flag is set', () {
        expect(command.ignoreUnexpectedPositionalArgs, isTrue);
      });

      test(
        'when the leaf command receives an extra positional argument '
        'then the command runs',
        () async {
          await runner.run(['build', 'extra']);

          expect(trace, ['build']);
        },
      );
    },
  );

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

  group('Given a command that throws a usage exception from run', () {
    const message = 'build: A target is required.';
    late List<String> trace;
    late StringBuffer err;
    late RecordingCommand<OptionDefinition> command;
    late TracingRunner runner;
    late CommandDefinition? seenFrom;
    late int handlerCalls;

    void setUpRunner({
      required final bool asynchronous,
      final bool suppressException = false,
    }) {
      trace = [];
      err = StringBuffer();
      seenFrom = null;
      handlerCalls = 0;
      command = RecordingCommand(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        body: (final _) {
          final error = CommandUsageException(message, command);
          if (asynchronous) return Future<String?>.error(error);
          throw error;
        },
      );
      runner = TracingRunner(
        trace,
        usageOutput: UsageOutputHandler(
          sinks: OutputSinks(err: err),
          exceptionSettings: UsageExceptionSettings(
            noUsageException: suppressException,
          ),
          addExceptionHandlers: [
            (final exception, final _, {required final fromCommand}) {
              handlerCalls++;
              seenFrom = fromCommand;
              return exception;
            },
          ],
        ),
        subcommands: [command],
      );
    }

    for (final asynchronous in [false, true]) {
      final when = asynchronous
          ? 'when run throws asynchronously'
          : 'when run throws synchronously';

      group(when, () {
        late UsageException? error;

        setUp(() async {
          setUpRunner(asynchronous: asynchronous);
          error = await _captureUsageError(() => runner.run(['build']));
        });

        test('then the usage exception is thrown', () {
          expect(
            error,
            isA<CommandUsageException>().having(
              (final e) => e.message,
              'message',
              message,
            ),
          );
        });

        test('then the handler runs once for the runner', () {
          expect(handlerCalls, 1);
          expect(seenFrom, same(runner));
        });

        test('then the error and the command usage are printed once', () {
          expect(err.toString(), '$message\n\n${command.usage}');
        });
      });
    }

    group('when an asynchronous run throws and exceptions are suppressed', () {
      late String? result;

      setUp(() async {
        setUpRunner(asynchronous: true, suppressException: true);
        result = await runner.run(['build']);
      });

      test('then the runner returns null', () {
        expect(result, isNull);
      });

      test('then the error is printed once', () {
        expect(message.allMatches(err.toString()), hasLength(1));
        expect(err.toString(), contains(command.usage));
      });
    });
  });

  group('Given a command that throws a non-usage exception from run', () {
    late List<String> trace;
    late StringBuffer err;
    late TracingRunner runner;
    late int handlerCalls;
    late Object? error;

    setUp(() {
      trace = [];
      err = StringBuffer();
      handlerCalls = 0;
      runner = TracingRunner(
        trace,
        usageOutput: UsageOutputHandler(
          sinks: OutputSinks(err: err),
          addExceptionHandlers: [
            (final exception, final _, {required final fromCommand}) {
              handlerCalls++;
              return exception;
            },
          ],
        ),
        subcommands: [
          RecordingCommand(
            name: 'build',
            description: 'Build the app',
            trace: trace,
            body: (final _) async {
              throw StateError('boom');
            },
          ),
        ],
      );
    });

    group('when the command is invoked', () {
      setUp(() async {
        try {
          await runner.run(['build']);
          error = null;
        } on Object catch (caught) {
          error = caught;
        }
      });

      test('then the exception propagates', () {
        expect(error, isA<StateError>());
      });

      test('then the usage handler is not called', () {
        expect(handlerCalls, 0);
      });

      test('then no error output is printed', () {
        expect(err.toString(), isEmpty);
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

  group('Given a runner with a global flag and a pass-through command', () {
    const verbose = FlagOption(
      argName: 'verbose',
      argAbbrev: 'v',
      negatable: false,
      defaultsTo: false,
    );

    late List<String> trace;
    late StringBuffer out;
    late List<String>? received;
    late bool? rootVerbose;
    late TracingRunner runner;

    setUp(() {
      trace = [];
      out = StringBuffer();
      received = null;
      rootVerbose = null;
      runner = TracingRunner(
        trace,
        globalOptions: [verbose],
        usageOutput: UsageOutputHandler(
          sinks: OutputSinks(out: out, err: StringBuffer()),
          exceptionSettings: const UsageExceptionSettings(
            noUsageExceptionOutput: true,
          ),
        ),
        subcommands: [
          _PassThroughCommand(
            trace: trace,
            body: (final context) {
              received = context.config.remainingPosArgs;
              rootVerbose = context.root().config.optionalValue(verbose);
              return null;
            },
          ),
        ],
      );
    });

    group('when options, words and -- follow the command', () {
      const rest = ['build', '--unknown=1', '-x', '--', '-', 'y'];

      setUp(() async {
        await runner.run(['relay', ...rest]);
      });

      test('then the command runs', () {
        expect(trace, ['relay']);
      });

      test('then the command receives them all, as written', () {
        expect(received, rest);
      });
    });

    group('when the help option follows the command', () {
      setUp(() async {
        await runner.run(['relay', '--help']);
      });

      test('then the command receives it', () {
        expect(received, ['--help']);
      });

      test('then no usage is printed', () {
        expect(out.toString(), isEmpty);
      });
    });

    group('when the global flag is given before and after the command', () {
      setUp(() async {
        await runner.run(['-v', 'relay', '-v']);
      });

      test('then the root command is given the one before it', () {
        expect(rootVerbose, isTrue);
      });

      test('then the command receives the one after it', () {
        expect(received, ['-v']);
      });
    });

    test('when the global flag is given after the command only '
        'then the root command is not given it', () async {
      await runner.run(['relay', '-v']);

      expect(rootVerbose, isFalse);
    });

    test('when nothing follows the command '
        'then the command receives no arguments', () async {
      await runner.run(['relay']);

      expect(received, isEmpty);
    });

    group('when an unknown option precedes the command', () {
      late UsageException? error;

      setUp(() async {
        error = await _captureUsageError(
          () => runner.run(['--missing', 'relay', 'x']),
        );
      });

      test('then the unknown option is reported', () {
        expect(error?.message, 'tool: Unknown option: --missing.');
      });

      test('then the command does not run', () {
        expect(trace, isEmpty);
      });
    });

    group('when the help option precedes the command', () {
      setUp(() async {
        await runner.run(['--help', 'relay', 'x']);
      });

      test('then the usage of the command is printed, '
          'with arguments in its synopsis', () {
        expect(out.toString(), contains('Usage: tool relay [arguments]\n'));
      });

      test('then the command does not run', () {
        expect(trace, isEmpty);
      });
    });

    test('when the help command is given the command '
        'then the usage of the command is printed', () async {
      await runner.run(['help', 'relay']);

      expect(out.toString(), contains('Usage: tool relay [arguments]\n'));
    });
  });
}

/// A command named `relay` that passes its arguments through.
class _PassThroughCommand extends RecordingCommand<OptionDefinition> {
  _PassThroughCommand({required super.trace, super.body})
    : super(name: 'relay', description: 'Run the other tool.');

  @override
  bool get passThroughArgs => true;
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
