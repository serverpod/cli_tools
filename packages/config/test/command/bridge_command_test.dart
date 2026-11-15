import 'dart:async';

import 'package:config/command.dart';
import 'package:config/config.dart';
import 'package:test/test.dart';

import 'command_fixtures.dart';

void main() {
  group('Given a bridge command with only a name and description', () {
    late _NamedBridge command;

    setUp(() {
      command = _NamedBridge(
        name: 'plain',
        description: 'Does the plain thing',
      );
    });

    test(
      'when reading the usage definition then the description is copied',
      () {
        expect(command.usageDefinition.description, 'Does the plain thing');
      },
    );

    test('when reading the usage definition then there is no footer', () {
      expect(command.usageDefinition.usageFooter, isNull);
    });

    test('when reading the usage definition then the category is empty', () {
      expect(command.usageDefinition.category, isEmpty);
    });

    test('when reading the usage definition then the command is visible', () {
      expect(command.usageDefinition.hidden, isFalse);
    });

    test('when reading the alias definition then there are no aliases', () {
      expect(command.aliasesDefinition.aliases, isEmpty);
    });

    test(
      'when reading the alias definition '
      'then there are no suggestion aliases',
      () {
        expect(command.aliasesDefinition.suggestionAliases, isEmpty);
      },
    );

    test('when reading the summary then it is the description', () {
      expect(command.summary, 'Does the plain thing');
    });

    test(
      'when reading the invocation '
      'then it is the command name and arguments',
      () {
        expect(command.invocation, 'plain [arguments]');
      },
    );

    test('when asked whether it takes arguments then it does not', () {
      expect(command.takesArguments, isFalse);
    });

    group('when it is added to a runner', () {
      setUp(() {
        _runner(subcommands: [command]);
      });

      test('then its usage shows the description and no footer', () {
        expect(
          command.usage,
          _usage(const [
            'Does the plain thing',
            '',
            'Usage: tool plain',
            '',
            'Run "tool help" to see global options.',
          ]),
        );
      });
    });

    group('when it is run', () {
      late String? result;

      setUp(() async {
        result = await _runner(subcommands: [command]).run(['plain']);
      });

      test('then the run result is returned', () {
        expect(result, 'plain');
      });
    });
  });

  group(
    'Given a bridge command whose description changes after first usageDescription access',
    () {
      late _MutableDescription command;

      setUp(() {
        command = _MutableDescription('First line\nkept in the definition');
        command.usageDefinition;
      });

      group('when the description changes', () {
        setUp(() {
          command.description = 'Second line\nignored by the definition';
        });

        test('then the usage definition keeps the original description', () {
          expect(
            command.usageDefinition.description,
            'First line\nkept in the definition',
          );
        });

        test('then the summary uses the new first line', () {
          expect(command.summary, 'Second line');
        });
      });
    },
  );

  group('Given a bridge command with legacy documentation members', () {
    late _DocumentedBridge command;

    setUp(() {
      command = _DocumentedBridge();
    });

    test(
      'when reading the usage definition then the description is copied',
      () {
        expect(
          command.usageDefinition.description,
          'Build the project.\nMore detail here.',
        );
      },
    );

    test('when reading the usage definition then the footer is copied', () {
      expect(command.usageDefinition.usageFooter, 'See the docs.');
    });

    test('when reading the usage definition then the category is copied', () {
      expect(command.usageDefinition.category, 'Project');
    });

    test('when reading the usage definition then the command is visible', () {
      expect(command.usageDefinition.hidden, isFalse);
    });

    test('when reading the alias definition then the aliases are copied', () {
      expect(command.aliasesDefinition.aliases, ['b', 'compile']);
    });

    test(
      'when reading the alias definition '
      'then the suggestion aliases are copied',
      () {
        expect(command.aliasesDefinition.suggestionAliases, ['bld']);
      },
    );

    test(
      'when reading the summary '
      'then it is the first line of the description',
      () {
        expect(command.summary, 'Build the project.');
      },
    );

    group('when it is added to a runner beside another command', () {
      late CommandRunner<OptionDefinition, String> runner;

      setUp(() {
        runner = _runner(
          subcommands: [
            command,
            _NamedBridge(name: 'shown', description: 'Shown in help'),
            _HiddenBridge(),
          ],
        );
      });

      test('then its usage shows the full description and the footer', () {
        expect(
          command.usage,
          _usage(const [
            'Build the project.',
            'More detail here.',
            '',
            'Usage: tool build',
            '',
            'Run "tool help" to see global options.',
            '',
            'See the docs.',
          ]),
        );
      });

      test(
        'then the runner usage groups it by category '
        'and omits the hidden command',
        () {
          expect(
            runner.usage,
            _usage(const [
              'Tools',
              '',
              'Usage: tool [global-options] <command> [arguments]',
              '',
              'Global options:',
              '-h, --help    Print this usage information.',
              '',
              'Available commands:',
              '  shown   Shown in help',
              '',
              'Project',
              '  build   Build the project.',
              '',
              'Run "tool help <command>" for more information about a command.',
            ]),
          );
        },
      );

      group('when an alias is used', () {
        late String? result;

        setUp(() async {
          result = await runner.run(['compile']);
        });

        test('then the command runs', () {
          expect(result, 'build');
        });
      });

      group('when a suggestion alias is used', () {
        late UsageException? error;
        late String? result;

        setUp(() async {
          result = null;
          error = await _captureUsageError(() async {
            result = await runner.run(['bld']);
          });
        });

        test('then the word is reported as an unknown subcommand', () {
          expect(
            error?.message,
            'tool: Unknown subcommand: "bld" (Did you mean build?)',
          );
        });

        test('then the command does not run', () {
          expect(result, isNull);
        });
      });

      group('when the hidden command is invoked by name', () {
        late String? result;

        setUp(() async {
          result = await runner.run(['secret']);
        });

        test('then the hidden command runs', () {
          expect(result, 'secret');
        });
      });
    });
  });

  group('Given a bridge command with a subcommand', () {
    late _NamedBridge build;
    late _NamedBridge check;

    setUp(() {
      check = _NamedBridge(name: 'check', description: 'Check the app');
      build = _NamedBridge(
        name: 'build',
        description: 'Build the app',
        subcommands: [check],
      );
    });

    test('when reading the invocation then it asks for a subcommand', () {
      expect(build.invocation, 'build <subcommand> [arguments]');
    });

    test(
      'when reading the nested command invocation '
      'then it is that command name and arguments',
      () {
        expect(check.invocation, 'check [arguments]');
      },
    );
  });

  group('Given a bridge branch that can run as a leaf', () {
    late _NamedBridge command;

    setUp(() {
      command = _NamedBridge(
        name: 'build',
        description: 'Build the app',
        canRunAsLeafCommand: true,
        subcommands: [
          _NamedBridge(name: 'check', description: 'Check the app'),
        ],
      );
    });

    test('when reading the invocation then it asks for a subcommand', () {
      expect(command.invocation, 'build <subcommand> [arguments]');
    });
  });

  group('Given a bridge command that starts without subcommands', () {
    late _NamedBridge command;

    setUp(() {
      command = _NamedBridge(name: 'build', description: 'Build the app');
    });

    group('when a subcommand is added', () {
      setUp(() {
        command.addSubcommand(
          _NamedBridge(name: 'check', description: 'Check the app'),
        );
      });

      test('then the invocation asks for a subcommand', () {
        expect(command.invocation, 'build <subcommand> [arguments]');
      });
    });
  });

  group('Given a bridge command with only a named option', () {
    late _NamedBridge command;

    setUp(() {
      command = _NamedBridge(
        name: 'build',
        description: 'Build the app',
        options: const [
          FlagOption(argName: 'release', defaultsTo: false),
        ],
      );
    });

    test('when asked whether it takes arguments then it does not', () {
      expect(command.takesArguments, isFalse);
    });
  });

  group('Given a bridge command with a positional option', () {
    late _NamedBridge command;

    setUp(() {
      command = _NamedBridge(
        name: 'build',
        description: 'Build the app',
        options: const [StringOption(argPos: 0)],
        body: (final context) => context.config.findValueOf<String>(argPos: 0),
      );
    });

    test('when asked whether it takes arguments then it does', () {
      expect(command.takesArguments, isTrue);
    });

    group('when it is run with a positional word', () {
      late String? result;

      setUp(() async {
        result = await _runner(
          subcommands: [command],
        ).run(['build', 'lib/main.dart']);
      });

      test('then run receives that word', () {
        expect(result, 'lib/main.dart');
      });
    });
  });

  group('Given a bridge command with a positional persistent option', () {
    late _NamedBridge command;

    setUp(() {
      command = _NamedBridge(
        name: 'build',
        description: 'Build the app',
        persistentOptions: const [StringOption(argPos: 0)],
      );
    });

    test('when asked whether it takes arguments then it does', () {
      expect(command.takesArguments, isTrue);
    });
  });

  group('Given a bridge command registered on a runner', () {
    late _NamedBridge command;
    late _CapturedUsage usage;

    setUp(() {
      usage = _CapturedUsage();
      command = _NamedBridge(name: 'build', description: 'Build the app');
      CommandRunner<OptionDefinition, String>(
        'tool',
        'Tools',
        usageOutput: usage.handler,
        completion: CompletionSettings.disabled,
        subcommands: [command],
      );
    });

    group('when usage is printed', () {
      setUp(() {
        command.printUsage();
      });

      test('then the command usage is written to standard output', () {
        expect(usage.out.toString(), command.usage);
      });

      test('then standard error stays empty', () {
        expect(usage.err.toString(), isEmpty);
      });
    });

    group('when a usage exception is raised', () {
      late UsageException? error;

      setUp(() {
        error = _throwUsageException(command, 'Missing target.');
      });

      test('then the given message is reported', () {
        expect(error?.message, 'Missing target.');
      });

      test('then the command usage is attached', () {
        expect(error?.usage, command.usage);
      });
    });
  });
}

CommandRunner<OptionDefinition, String> _runner({
  required final List<Command<OptionDefinition, String>> subcommands,
}) {
  return CommandRunner(
    'tool',
    'Tools',
    subcommands: subcommands,
    usageOutput: noUsageErrorOutput,
    completion: CompletionSettings.disabled,
  );
}

String _usage(final Iterable<String> lines) => '${lines.join('\n')}\n';

Future<UsageException?> _captureUsageError(
  final Future<void> Function() body,
) async {
  try {
    await body();
  } on UsageException catch (error) {
    return error;
  }
  return null;
}

UsageException? _throwUsageException(
  final BridgeCommand<OptionDefinition, String> command,
  final String message,
) {
  try {
    command.usageException(message);
  } on UsageException catch (error) {
    return error;
  }
}

class _CapturedUsage {
  final out = StringBuffer();
  final err = StringBuffer();

  late final UsageOutputHandler handler = UsageOutputHandler(
    sinks: OutputSinks(out: out, err: err),
  );
}

class _NamedBridge extends BridgeCommand<OptionDefinition, String> {
  _NamedBridge({
    required this.name,
    required this.description,
    super.persistentOptions,
    super.options,
    super.subcommands,
    super.canRunAsLeafCommand,
    this.body,
  });

  @override
  final String name;

  @override
  final String description;

  final FutureOr<String?> Function(
    CommandContext<OptionDefinition, String> context,
  )?
  body;

  @override
  FutureOr<String?> run(
    final CommandContext<OptionDefinition, String> context,
  ) {
    final body = this.body;
    if (body != null) return body(context);
    return name;
  }
}

class _MutableDescription extends BridgeCommand<OptionDefinition, String> {
  _MutableDescription(this.description);

  @override
  String get name => 'plain';

  @override
  String description;

  @override
  String? run(final CommandContext<OptionDefinition, String> context) => name;
}

class _DocumentedBridge extends BridgeCommand<OptionDefinition, String> {
  @override
  String get name => 'build';

  @override
  String get description => 'Build the project.\nMore detail here.';

  @override
  String get category => 'Project';

  @override
  String? get usageFooter => 'See the docs.';

  @override
  List<String> get aliases => const ['b', 'compile'];

  @override
  List<String> get suggestionAliases => const ['bld'];

  @override
  String? run(final CommandContext<OptionDefinition, String> context) => name;
}

class _HiddenBridge extends BridgeCommand<OptionDefinition, String> {
  @override
  String get name => 'secret';

  @override
  String get description => 'Hidden command';

  @override
  bool get hidden => true;

  @override
  String? run(final CommandContext<OptionDefinition, String> context) => name;
}
