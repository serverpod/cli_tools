import 'package:config/command.dart';
import 'package:config/config.dart';
import 'package:test/test.dart';

import 'command_fixtures.dart';

void main() {
  group('Given a usage handler with captured sinks', () {
    late _CapturedUsage usage;
    late RecordingCommand greet;
    late _DelegateHandler handler;

    setUp(() {
      usage = _CapturedUsage();
      greet = _greet([]);
      handler = _DelegateHandler(
        (final exception, final _, final _) => exception,
      );
    });

    group('when usage is printed', () {
      setUp(() {
        usage
            .output(addExceptionHandlers: [handler.onUsageException])
            .printUsage(greet);
      });

      test('then that command is written to standard output', () {
        expect(usage.out.toString(), _greetUsage);
      });

      test('then standard error stays empty', () {
        expect(usage.err.toString(), isEmpty);
      });

      test('then exception handlers are not called', () {
        expect(handler.calls, 0);
      });
    });
  });

  group('Given a command usage exception', () {
    late _CapturedUsage usage;
    late RecordingCommand greet;
    late RecordingCommand tool;
    late CommandUsageException exception;
    late UsageException? result;

    setUp(() {
      usage = _CapturedUsage();
      greet = _greet([]);
      tool = _tool([]);
      exception = CommandUsageException(_missingName, greet);
      result = usage.output().onUsageException(
        exception,
        fromCommand: tool,
      );
    });

    test('when it is handled then that same exception is returned', () {
      expect(result, same(exception));
    });

    test(
      'when it is handled '
      "then the error and that command's usage are printed",
      () {
        expect(
          usage.err.toString(),
          _errorThenUsage(_missingName, _greetUsage),
        );
      },
    );

    test('when it is handled then standard output stays empty', () {
      expect(usage.out.toString(), isEmpty);
    });
  });

  group('Given a usage exception that carries usage text', () {
    late _CapturedUsage usage;
    late RecordingCommand tool;
    late UsageException exception;

    setUp(() {
      usage = _CapturedUsage();
      tool = _tool([]);
      exception = UsageException('bad input', 'Try --help');
    });

    group('when no command is attached', () {
      setUp(() {
        usage.output().onUsageException(exception, fromCommand: null);
      });

      test('then the message and usage text are printed', () {
        expect(
          usage.err.toString(),
          _errorThenUsage('bad input', 'Try --help\n'),
        );
      });
    });

    group('when an originating command is attached', () {
      late UsageException? result;

      setUp(() {
        result = usage.output().onUsageException(
          exception,
          fromCommand: tool,
        );
      });

      test('then the usage text is followed by that command', () {
        expect(
          usage.err.toString(),
          _errorUsageAndCommand('bad input', 'Try --help', _toolUsage),
        );
      });

      test('then the exception is returned', () {
        expect(result, same(exception));
      });
    });

    group('when the usage text is empty and a command is attached', () {
      setUp(() {
        usage.output().onUsageException(
          UsageException('bad input', ''),
          fromCommand: tool,
        );
      });

      test('then that command is printed without a separator', () {
        expect(
          usage.err.toString(),
          _errorThenUsage('bad input', _toolUsage),
        );
      });
    });

    group('when the usage text is empty and no command is attached', () {
      setUp(() {
        usage.output().onUsageException(
          UsageException('bad input', ''),
          fromCommand: null,
        );
      });

      test('then only the message is printed', () {
        expect(usage.err.toString(), 'bad input\n\n');
      });
    });
  });

  group('Given usage exception output is disabled', () {
    late _CapturedUsage usage;
    late UsageException exception;
    late UsageException? result;

    setUp(() {
      usage = _CapturedUsage();
      exception = CommandUsageException(_missingName, _greet([]));
      result = usage
          .output(
            exceptionSettings: const UsageExceptionSettings(
              noUsageExceptionOutput: true,
            ),
          )
          .onUsageException(exception, fromCommand: _tool([]));
    });

    test(
      'when a command usage exception is handled then nothing is printed',
      () {
        expect(usage.err.toString(), isEmpty);
        expect(usage.out.toString(), isEmpty);
      },
    );

    test(
      'when a command usage exception is handled '
      'then the exception is still returned',
      () {
        expect(result, same(exception));
      },
    );
  });

  group('Given usage exceptions are not thrown', () {
    late _CapturedUsage usage;
    late UsageException? result;

    setUp(() {
      usage = _CapturedUsage();
      result = usage
          .output(
            exceptionSettings: const UsageExceptionSettings(
              noUsageException: true,
            ),
          )
          .onUsageException(
            CommandUsageException(_missingName, _greet([])),
            fromCommand: null,
          );
    });

    test(
      'when a command usage exception is handled '
      'then the error and command usage are still printed',
      () {
        expect(
          usage.err.toString(),
          _errorThenUsage(_missingName, _greetUsage),
        );
      },
    );

    test(
      'when a command usage exception is handled '
      'then no exception is returned',
      () {
        expect(result, isNull);
      },
    );
  });

  group('Given usage exceptions are neither printed nor thrown', () {
    late _CapturedUsage usage;
    late UsageException? result;

    setUp(() {
      usage = _CapturedUsage();
      result = usage
          .output(
            exceptionSettings: const UsageExceptionSettings(
              noUsageException: true,
              noUsageExceptionOutput: true,
            ),
          )
          .onUsageException(
            CommandUsageException(_missingName, _greet([])),
            fromCommand: null,
          );
    });

    test(
      'when a command usage exception is handled then nothing is printed',
      () {
        expect(usage.err.toString(), isEmpty);
      },
    );

    test(
      'when a command usage exception is handled '
      'then no exception is returned',
      () {
        expect(result, isNull);
      },
    );
  });

  group('Given additional exception handlers', () {
    late _CapturedUsage usage;
    late UsageException original;

    setUp(() {
      usage = _CapturedUsage();
      original = CommandUsageException(_missingName, _greet([]));
    });

    group('when an earlier handler rewrites the exception', () {
      late _DelegateHandler first;
      late _DelegateHandler second;
      late UsageException? result;

      setUp(() {
        first = _DelegateHandler(
          (final _, final _, final _) =>
              UsageException('rewritten', 'Try --help'),
        );
        second = _DelegateHandler(
          (final exception, final _, final _) => exception,
        );
        result = usage
            .output(
              addExceptionHandlers: [
                first.onUsageException,
                second.onUsageException,
              ],
            )
            .onUsageException(original, fromCommand: _tool([]));
      });

      test('then each handler sees the exception from the previous one', () {
        expect(first.messages, [_missingName]);
        expect(second.messages, ['rewritten']);
      });

      test(
        'then the rewritten usage text and originating command are printed',
        () {
          expect(
            usage.err.toString(),
            _errorUsageAndCommand('rewritten', 'Try --help', _toolUsage),
          );
        },
      );

      test('then the rewritten exception is returned', () {
        expect(result?.message, 'rewritten');
        expect(result, isNot(isA<CommandUsageException>()));
      });
    });

    group('when an earlier handler stops the exception', () {
      late _DelegateHandler first;
      late _DelegateHandler second;
      late UsageException? result;

      setUp(() {
        first = _DelegateHandler((final _, final _, final _) => null);
        second = _DelegateHandler(
          (final exception, final _, final _) => exception,
        );
        result = usage
            .output(
              addExceptionHandlers: [
                first.onUsageException,
                second.onUsageException,
              ],
            )
            .onUsageException(original, fromCommand: null);
      });

      test('then later handlers do not run', () {
        expect(first.calls, 1);
        expect(second.calls, 0);
      });

      test('then nothing is printed', () {
        expect(usage.err.toString(), isEmpty);
      });

      test('then no exception is returned', () {
        expect(result, isNull);
      });
    });

    group('when a handler rewrites the exception and throwing is disabled', () {
      late UsageException? result;

      setUp(() {
        result = usage
            .output(
              exceptionSettings: const UsageExceptionSettings(
                noUsageException: true,
              ),
              addExceptionHandlers: [
                _DelegateHandler(
                  (final _, final _, final _) =>
                      UsageException('rewritten', ''),
                ).onUsageException,
              ],
            )
            .onUsageException(original, fromCommand: null);
      });

      test('then the rewritten message is printed', () {
        expect(usage.err.toString(), 'rewritten\n\n');
      });

      test('then no exception is returned', () {
        expect(result, isNull);
      });
    });
  });

  group('Given a simple exception handler', () {
    late _CapturedUsage usage;
    late RecordingCommand tool;
    late UsageException exception;

    setUp(() {
      usage = _CapturedUsage();
      tool = _tool([]);
      exception = CommandUsageException(_missingName, _greet([]));
    });

    group('when a command usage exception is handled', () {
      late UsageOutputHandler output;
      late List<String> messages;
      late UsageOutputHandler? seenOutput;
      late CommandDefinition? seenCommand;
      late UsageException? result;

      setUp(() {
        messages = [];
        seenOutput = null;
        seenCommand = null;
        output = usage.output(
          addExceptionHandlers: [
            UsageExceptions.simpleHandler((
              final error,
              final usageOutput,
              final fromCommand,
            ) {
              messages.add(error.message);
              seenOutput = usageOutput;
              seenCommand = fromCommand;
            }),
          ],
        );
        result = output.onUsageException(exception, fromCommand: tool);
      });

      test('then the callback receives that exception', () {
        expect(messages, [_missingName]);
      });

      test('then the callback receives the usage output', () {
        expect(seenOutput, same(output));
      });

      test('then the callback receives the originating command', () {
        expect(seenCommand, same(tool));
      });

      test('then the error and command usage are still printed', () {
        expect(
          usage.err.toString(),
          _errorThenUsage(_missingName, _greetUsage),
        );
      });

      test('then the original exception is returned', () {
        expect(result, same(exception));
      });
    });

    group('when another handler follows it', () {
      late _DelegateHandler follower;
      late UsageException? result;

      setUp(() {
        follower = _DelegateHandler(
          (final error, final _, final _) => error,
        );
        result = usage
            .output(
              addExceptionHandlers: [
                UsageExceptions.simpleHandler((final _, final _, final _) {}),
                follower.onUsageException,
              ],
            )
            .onUsageException(exception, fromCommand: tool);
      });

      test('then the following handler sees the original exception', () {
        expect(follower.messages, [_missingName]);
      });

      test('then the original exception is returned', () {
        expect(result, same(exception));
      });
    });

    group('when it replaces the standard handler', () {
      late List<String> messages;
      late UsageException? result;

      setUp(() {
        messages = [];
        result = usage
            .outputReplacing([
              UsageExceptions.simpleHandler((
                final error,
                final _,
                final _,
              ) {
                messages.add(error.message);
              }),
            ])
            .onUsageException(exception, fromCommand: tool);
      });

      test('then the callback still runs', () {
        expect(messages, [_missingName]);
      });

      test('then nothing is printed', () {
        expect(usage.err.toString(), isEmpty);
        expect(usage.out.toString(), isEmpty);
      });

      test('then the original exception is returned', () {
        expect(result, same(exception));
      });
    });
  });

  group('Given the standard exception handler is replaced', () {
    late _CapturedUsage usage;
    late UsageException exception;

    setUp(() {
      usage = _CapturedUsage();
      exception = CommandUsageException(_missingName, _greet([]));
    });

    group('when the replacement returns the exception', () {
      late UsageException? result;

      setUp(() {
        result = usage
            .outputReplacing([
              _DelegateHandler(
                (final error, final _, final _) => error,
              ).onUsageException,
            ])
            .onUsageException(exception, fromCommand: _tool([]));
      });

      test('then the standard usage text is not printed', () {
        expect(usage.err.toString(), isEmpty);
      });

      test('then the exception is returned', () {
        expect(result, same(exception));
      });
    });

    group('when no handlers are installed', () {
      late UsageException? result;

      setUp(() {
        result = usage
            .outputReplacing(const [])
            .onUsageException(
              exception,
              fromCommand: null,
            );
      });

      test('then nothing is printed', () {
        expect(usage.err.toString(), isEmpty);
      });

      test('then the exception is returned unchanged', () {
        expect(result, same(exception));
      });
    });

    group('when a custom exception printer is installed', () {
      late _CapturePrinter printer;
      late RecordingCommand tool;
      late UsageException? result;

      setUp(() {
        printer = _CapturePrinter();
        tool = _tool([]);
        result = usage
            .outputReplacing([
              StandardUsageExceptionHandler(
                exceptionPrinter: printer,
              ).onUsageException,
            ])
            .onUsageException(exception, fromCommand: tool);
      });

      test(
        'then the printer receives the exception and originating command',
        () {
          expect(printer.exception, same(exception));
          expect(printer.fromCommand, same(tool));
        },
      );

      test('then the exception is returned', () {
        expect(result, same(exception));
      });

      test('then the error sink stays empty', () {
        expect(usage.err.toString(), isEmpty);
      });
    });

    group('when output is disabled for a custom exception printer', () {
      late _CapturePrinter printer;

      setUp(() {
        printer = _CapturePrinter();
        usage
            .outputReplacing(
              [
                StandardUsageExceptionHandler(
                  exceptionPrinter: printer,
                ).onUsageException,
              ],
              exceptionSettings: const UsageExceptionSettings(
                noUsageExceptionOutput: true,
              ),
            )
            .onUsageException(exception, fromCommand: null);
      });

      test('then the printer is not called', () {
        expect(printer.calls, 0);
      });
    });
  });

  group('Given a custom usage printer', () {
    late _CapturedUsage usage;
    late RecordingCommand greet;
    late RecordingCommand tool;
    late UsageOutputHandler output;

    setUp(() {
      usage = _CapturedUsage();
      greet = _greet([]);
      tool = _tool([]);
      output = usage.output(usagePrinter: const _NamedPrinter());
    });

    group('when usage is printed', () {
      setUp(() => output.printUsage(greet));

      test('then the custom printer writes to standard output', () {
        expect(usage.out.toString(), 'usage:greet\n');
      });
    });

    group('when a command usage exception is handled', () {
      setUp(() {
        output.onUsageException(
          CommandUsageException(_missingName, greet),
          fromCommand: tool,
        );
      });

      test("then the custom printer writes that exception's command", () {
        expect(
          usage.err.toString(),
          _errorThenUsage(_missingName, 'usage:greet\n'),
        );
      });
    });

    group('when a plain usage exception has an originating command', () {
      setUp(() {
        output.onUsageException(
          UsageException('bad input', 'Try --help'),
          fromCommand: tool,
        );
      });

      test('then the custom printer writes the originating command', () {
        expect(
          usage.err.toString(),
          _errorUsageAndCommand('bad input', 'Try --help', 'usage:tool\n'),
        );
      });
    });
  });

  group('Given a runner that does not throw usage exceptions', () {
    late List<String> trace;
    late _CapturedUsage usage;
    late TracingRunner runner;

    setUp(() {
      trace = [];
      usage = _CapturedUsage();
      runner = _runner(
        trace,
        usage.output(
          exceptionSettings: const UsageExceptionSettings(
            noUsageException: true,
          ),
        ),
      );
    });

    group('when a mandatory option is omitted', () {
      late Object? result;

      setUp(() {
        result = runner.runner(['greet']);
      });

      test('then the runner returns null', () {
        expect(result, isNull);
      });

      test('then the error and command usage are still printed', () {
        expect(
          usage.err.toString(),
          _errorThenUsage(_missingName, _greetUsage),
        );
      });

      test('then the command does not run', () {
        expect(trace, isEmpty);
      });
    });
  });

  group('Given a runner that does not print usage exceptions', () {
    late _CapturedUsage usage;
    late UsageException? error;

    setUp(() {
      usage = _CapturedUsage();
      final runner = _runner(
        [],
        usage.output(
          exceptionSettings: const UsageExceptionSettings(
            noUsageExceptionOutput: true,
          ),
        ),
      );
      error = _captureUsageError(() => runner.runner(['greet']));
    });

    test(
      'when a mandatory option is omitted '
      'then a usage exception is thrown',
      () {
        expect(
          error,
          isA<CommandUsageException>().having(
            (final exception) => exception.command.name,
            'command',
            'greet',
          ),
        );
      },
    );

    test(
      'when a mandatory option is omitted '
      'then nothing is printed',
      () {
        expect(usage.err.toString(), isEmpty);
        expect(usage.out.toString(), isEmpty);
      },
    );
  });

  group('Given a runner that neither prints nor throws usage exceptions', () {
    late List<String> trace;
    late _CapturedUsage usage;
    late TracingRunner runner;

    setUp(() {
      trace = [];
      usage = _CapturedUsage();
      runner = _runner(
        trace,
        usage.output(
          exceptionSettings: const UsageExceptionSettings(
            noUsageException: true,
            noUsageExceptionOutput: true,
          ),
        ),
      );
    });

    group('when a mandatory option is omitted', () {
      late Object? result;

      setUp(() {
        result = runner.runner(['greet']);
      });

      test('then the runner returns null', () {
        expect(result, isNull);
      });

      test('then nothing is printed', () {
        expect(usage.err.toString(), isEmpty);
      });

      test('then the command does not run', () {
        expect(trace, isEmpty);
      });
    });

    group('when --help is passed', () {
      late Object? result;

      setUp(() async {
        result = await runner.runner(['--help']);
      });

      test('then usage for the runner is printed to standard output', () {
        expect(usage.out.toString(), _runnerUsage);
      });

      test('then standard error stays empty', () {
        expect(usage.err.toString(), isEmpty);
      });

      test('then no command runs', () {
        expect(trace, isEmpty);
      });

      test('then no command result is returned', () {
        expect(result, isNull);
      });
    });
  });

  group('Given a runner with an additional exception handler', () {
    late List<String> trace;
    late _CapturedUsage usage;
    late _DelegateHandler handler;
    late TracingRunner runner;

    setUp(() {
      trace = [];
      usage = _CapturedUsage();
      handler = _DelegateHandler(
        (final exception, final _, final _) => exception,
      );
      runner = _runner(
        trace,
        usage.output(addExceptionHandlers: [handler.onUsageException]),
      );
    });

    group('when a mandatory option is omitted', () {
      late UsageException? error;

      setUp(() {
        error = _captureUsageError(() => runner.runner(['greet']));
      });

      test('then the handler receives the runner and its usage output', () {
        expect(handler.fromCommand, same(runner));
        expect(handler.usageOutput, same(runner.usageOutput));
      });

      test('then the handler sees the original error', () {
        expect(handler.messages, [_missingName]);
      });

      test('then the original exception is thrown', () {
        expect(error?.message, _missingName);
      });

      test('then the error and command usage are printed', () {
        expect(
          usage.err.toString(),
          _errorThenUsage(_missingName, _greetUsage),
        );
      });
    });

    group('when the handler replaces the exception', () {
      late UsageException replacement;
      late UsageException? error;

      setUp(() {
        replacement = UsageException('replaced', 'custom usage');
        handler = _DelegateHandler(
          (final _, final _, final _) => replacement,
        );
        runner = _runner(
          trace,
          usage.output(addExceptionHandlers: [handler.onUsageException]),
        );
        error = _captureUsageError(() => runner.runner(['greet']));
      });

      test('then the replacement is thrown', () {
        expect(error, same(replacement));
      });

      test(
        'then the replacement usage is printed '
        'with the runner usage after it',
        () {
          expect(
            usage.err.toString(),
            _errorUsageAndCommand('replaced', 'custom usage', _runnerUsage),
          );
        },
      );

      test('then the command does not run', () {
        expect(trace, isEmpty);
      });
    });

    group('when the handler stops the exception', () {
      late Object? result;

      setUp(() {
        handler = _DelegateHandler(
          (final exception, final output, final _) {
            output.sinks.err.writeln('logged ${exception.message}');
            return null;
          },
        );
        runner = _runner(
          trace,
          usage.output(addExceptionHandlers: [handler.onUsageException]),
        );
        result = runner.runner(['greet']);
      });

      test('then the runner returns null', () {
        expect(result, isNull);
      });

      test('then only the handler output is printed', () {
        expect(usage.err.toString(), 'logged $_missingName\n');
      });

      test('then the command does not run', () {
        expect(trace, isEmpty);
      });
    });
  });

  group('Given a runner whose standard exception handler is replaced', () {
    late List<String> trace;
    late _CapturedUsage usage;
    late _DelegateHandler handler;
    late UsageException? error;

    setUp(() {
      trace = [];
      usage = _CapturedUsage();
      handler = _DelegateHandler(
        (final exception, final _, final _) => exception,
      );
      final runner = _runner(
        trace,
        usage.outputReplacing([handler.onUsageException]),
      );
      error = _captureUsageError(() => runner.runner(['greet']));
    });

    test(
      'when a mandatory option is omitted '
      'then the replacement handler runs',
      () {
        expect(handler.messages, [_missingName]);
      },
    );

    test(
      'when a mandatory option is omitted '
      'then the standard usage text is not printed',
      () {
        expect(usage.err.toString(), isEmpty);
      },
    );

    test(
      'when a mandatory option is omitted '
      'then the exception is still thrown',
      () {
        expect(error?.message, _missingName);
      },
    );

    test(
      'when a mandatory option is omitted '
      'then the command does not run',
      () {
        expect(trace, isEmpty);
      },
    );
  });
}

TracingRunner _runner(
  final List<String> trace,
  final UsageOutputHandler usageOutput,
) {
  return TracingRunner(
    trace,
    usageOutput: usageOutput,
    subcommands: [_greet(trace)],
  );
}

RecordingCommand _greet(final List<String> trace) {
  return RecordingCommand(
    name: 'greet',
    description: 'Greet',
    trace: trace,
    options: const [
      StringOption(argName: 'name', mandatory: true),
    ],
  );
}

RecordingCommand _tool(final List<String> trace) {
  return RecordingCommand(
    name: 'tool',
    description: 'Tools',
    trace: trace,
  );
}

UsageException? _captureUsageError(final void Function() body) {
  try {
    body();
  } on UsageException catch (error) {
    return error;
  }
  return null;
}

String _usage(final Iterable<String> lines) => '${lines.join('\n')}\n';

String _errorThenUsage(final String message, final String usage) =>
    '$message\n\n$usage';

String _errorUsageAndCommand(
  final String message,
  final String usage,
  final String commandUsage,
) => '$message\n\n$usage\n---\n$commandUsage';

const _missingName = 'greet: Option `name` is mandatory.';

final String _greetUsage = _usage(const [
  'Command: greet',
  'Description: Greet',
  'Named options:',
  '  name',
]);

final String _toolUsage = _usage(const [
  'Command: tool',
  'Description: Tools',
]);

final String _runnerUsage = _usage(const [
  'Command: tool',
  'Description: Tools',
  'Subcommands:',
  '  greet',
  '  help',
]);

class _CapturedUsage {
  final out = StringBuffer();
  final err = StringBuffer();

  UsageSinks get sinks => UsageSinks(out: out, err: err);

  UsageOutputHandler output({
    final UsagePrinter? usagePrinter,
    final UsageExceptionSettings? exceptionSettings,
    final List<UsageExceptionHandler>? addExceptionHandlers,
  }) {
    return UsageOutputHandler(
      sinks: sinks,
      usagePrinter: usagePrinter ?? const StandardUsagePrinter(),
      exceptionSettings: exceptionSettings ?? const UsageExceptionSettings(),
      addExceptionHandlers: addExceptionHandlers,
    );
  }

  UsageOutputHandler outputReplacing(
    final List<UsageExceptionHandler> exceptionHandlers, {
    final UsageExceptionSettings? exceptionSettings,
  }) {
    return UsageOutputHandler.replace(
      sinks: sinks,
      exceptionSettings: exceptionSettings ?? const UsageExceptionSettings(),
      exceptionHandlers: exceptionHandlers,
    );
  }
}

class _DelegateHandler {
  _DelegateHandler(this._handle);

  final UsageException? Function(
    UsageException exception,
    UsageOutputHandler usageOutput,
    CommandDefinition? fromCommand,
  )
  _handle;

  final List<String> messages = [];
  CommandDefinition? fromCommand;
  UsageOutputHandler? usageOutput;
  int calls = 0;

  UsageException? onUsageException(
    final UsageException exception,
    final UsageOutputHandler usageOutput, {
    required final CommandDefinition? fromCommand,
  }) {
    calls++;
    messages.add(exception.message);
    this.fromCommand = fromCommand;
    this.usageOutput = usageOutput;
    return _handle(exception, usageOutput, fromCommand);
  }
}

class _NamedPrinter implements UsagePrinter {
  const _NamedPrinter();

  @override
  void print(final CommandDefinition command, final StringSink sink) {
    sink.writeln('usage:${command.name}');
  }
}

class _CapturePrinter implements UsageExceptionPrinter {
  UsageException? exception;
  CommandDefinition? fromCommand;
  int calls = 0;

  @override
  void printException(
    final UsageException exception, {
    required final UsageOutputHandler usageOutput,
    required final CommandDefinition? fromCommand,
  }) {
    calls++;
    this.exception = exception;
    this.fromCommand = fromCommand;
  }
}
