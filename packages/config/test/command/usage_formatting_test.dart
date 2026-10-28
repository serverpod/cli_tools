import 'package:config/command.dart';
import 'package:config/config.dart';
import 'package:test/test.dart';

void main() {
  group('Given a command with no options', () {
    late Command<OptionDefinition, void> command;

    setUp(() {
      command = _command(name: 'version', description: 'Show the version');
      _runner(subcommands: [command]);
    });

    test('when reading usage then the formatted usage is produced', () {
      expect(
        command.usage,
        _usage(const [
          'Show the version',
          '',
          'Usage: tool version',
          '',
          'Run "tool help" to see global options.',
        ]),
      );
    });
  });

  group('Given a command with a mandatory named option', () {
    late Command<OptionDefinition, void> command;

    setUp(() {
      command = _command(
        name: 'greet',
        description: 'Greet',
        options: const [
          StringOption(argName: 'name', mandatory: true),
        ],
      );
      _runner(subcommands: [command]);
    });

    test('when reading usage then the formatted usage is produced', () {
      expect(
        command.usage,
        _usage(const [
          'Greet',
          '',
          'Usage: tool greet --name=<name>',
          '',
          'Options:',
          '--name    ',
          '          (mandatory)',
          '',
          'Run "tool help" to see global options.',
        ]),
      );
    });
  });

  group(
    'Given a command with an abbreviation, a flag, and a positional option',
    () {
      late Command<OptionDefinition, void> command;

      setUp(() {
        command = _command(
          name: 'build',
          description: 'Build the app',
          aliases: const ['b'],
          options: const [
            StringOption(argName: 'target', argAbbrev: 't'),
            FlagOption(argName: 'release', defaultsTo: false),
            StringOption(argPos: 0),
          ],
        );
        _runner(subcommands: [command]);
      });

      test('when reading usage then the formatted usage is produced', () {
        expect(
          command.usage,
          _usage(const [
            'Build the app',
            '',
            'Usage: tool build [<arg0>] [--target=<target>] [--[no-]release]',
            '',
            'Options:',
            '-t, --target      ',
            '--[no-]release    ',
            '                  (defaults to false)',
            '                  ',
            '',
            'Run "tool help" to see global options.',
          ]),
        );
      });
    },
  );

  group('Given a command with an option and a subcommand', () {
    late Command<OptionDefinition, void> command;

    setUp(() {
      command = _command(
        name: 'remote',
        description: 'Manage remotes',
        aliases: const ['r'],
        options: const [
          StringOption(argName: 'env', argAbbrev: 'e'),
        ],
        subcommands: [
          _command(name: 'add', description: 'Add a remote'),
        ],
      );
      _runner(subcommands: [command]);
    });

    test('when reading usage then the formatted usage is produced', () {
      expect(
        command.usage,
        _usage(const [
          'Manage remotes',
          '',
          'Usage: tool remote [--env=<env>] <subcommand> [arguments]',
          '',
          'Options:',
          '-e, --env    ',
          '',
          'Available subcommands:',
          '  add   Add a remote',
          '',
          'Run "tool help" to see global options.',
        ]),
      );
    });
  });

  group('Given a command with a mandatory option and a subcommand', () {
    late Command<OptionDefinition, void> command;

    setUp(() {
      command = _command(
        name: 'build',
        description: 'Build the app',
        options: const [
          StringOption(argName: 'target', mandatory: true),
        ],
        subcommands: [
          _command(name: 'version', description: 'Show the version'),
        ],
      );
      _runner(subcommands: [command]);
    });

    test('when reading usage then the formatted usage is produced', () {
      expect(
        command.usage,
        _usage(const [
          'Build the app',
          '',
          'Usage: tool build --target=<target> <subcommand> [arguments]',
          '',
          'Options:',
          '--target    ',
          '            (mandatory)',
          '',
          'Available subcommands:',
          '  version   Show the version',
          '',
          'Run "tool help" to see global options.',
        ]),
      );
    });
  });

  group('Given a runner with no subcommands', () {
    late CommandRunner<OptionDefinition, void> runner;

    setUp(() {
      runner = _runner();
    });

    test('when reading usage then the formatted usage is produced', () {
      expect(
        runner.usage,
        _usage(const [
          'Tools',
          '',
          'Usage: tool [global-options] <command> [arguments]',
          '',
          'Global options:',
          '-h, --help    Show the usage help for a command.',
          '              (defaults to false)',
          '',
        ]),
      );
    });
  });

  group('Given a runner with a subcommand', () {
    late CommandRunner<OptionDefinition, void> runner;

    setUp(() {
      runner = _runner(
        subcommands: [
          _command(name: 'greet', description: 'Greet'),
        ],
      );
    });

    test('when reading usage then the formatted usage is produced', () {
      expect(
        runner.usage,
        _usage(const [
          'Tools',
          '',
          'Usage: tool [global-options] <command> [arguments]',
          '',
          'Global options:',
          '-h, --help    Show the usage help for a command.',
          '              (defaults to false)',
          '',
          'Available commands:',
          '  greet   Greet',
          '',
          'Run "tool help <command>" for more information about a command.',
        ]),
      );
    });
  });

  group('Given a runner with a build command', () {
    late CommandRunner<OptionDefinition, void> runner;

    setUp(() {
      runner = _runner(
        subcommands: [
          _command(name: 'build', description: 'Build the app'),
        ],
      );
    });

    test('when reading usage then the formatted usage is produced', () {
      expect(
        runner.usage,
        _usage(const [
          'Tools',
          '',
          'Usage: tool [global-options] <command> [arguments]',
          '',
          'Global options:',
          '-h, --help    Show the usage help for a command.',
          '              (defaults to false)',
          '',
          'Available commands:',
          '  build   Build the app',
          '',
          'Run "tool help <command>" for more information about a command.',
        ]),
      );
    });
  });

  group('Given a runner with a mandatory global option', () {
    late CommandRunner<OptionDefinition, void> runner;

    setUp(() {
      runner = _runner(
        globalOptions: const [
          StringOption(argName: 'verbose', mandatory: true),
          CommandRunnerBuiltinOptions.help,
        ],
        subcommands: [
          _command(name: 'greet', description: 'Greet'),
        ],
      );
    });

    test('when reading usage then the formatted usage is produced', () {
      expect(
        runner.usage,
        _usage(const [
          'Tools',
          '',
          'Usage: tool [global-options] <command> [arguments]',
          '',
          'Global options:',
          '--verbose     ',
          '              (mandatory)',
          '-h, --help    Show the usage help for a command.',
          '              (defaults to false)',
          '',
          'Available commands:',
          '  greet   Greet',
          '',
          'Run "tool help <command>" for more information about a command.',
        ]),
      );
    });
  });

  group('Given a help command for a runner with a hidden command', () {
    late CommandDefinition help;

    setUp(() {
      final runner = _runner(
        subcommands: [
          _command(name: 'build', description: 'Build the app'),
          _command(
            name: 'secret',
            description: 'Hidden command',
            hidden: true,
          ),
        ],
      );
      help = runner.subcommands.firstWhere(
        (final command) => command.name == 'help',
      );
    });

    test('when reading usage then the formatted usage is produced', () {
      expect(
        help.usage,
        _usage(const [
          'Show help for a command.',
          '',
          'Usage: tool help <subcommand> [arguments]',
          '   or: tool help',
          '',
          'Available subcommands:',
          '  build   Build the app',
          '',
          'Run "tool help" to see global options.',
        ]),
      );
    });
  });

  group('Given a subcommand with a flag', () {
    late Command<OptionDefinition, void> command;

    setUp(() {
      command = _command(
        name: 'date',
        description: 'Show the date',
        options: const [
          FlagOption(argName: 'utc', negatable: false),
        ],
      );
      _runner(subcommands: [command]);
    });

    test(
      'when reading usage then the synopsis includes the parent command',
      () {
        expect(
          command.usage,
          contains('Usage: tool date [--utc]'),
        );
      },
    );
  });

  group('Given persistent, positional, and named options', () {
    late Command<OptionDefinition, void> command;

    setUp(() {
      command = _command(
        name: 'copy',
        description: 'Copy a file',
        persistentOptions: const [
          FlagOption(argName: 'verbose', negatable: false),
        ],
        options: const [
          StringOption(argPos: 0, valueHelp: 'file', mandatory: true),
          StringOption(
            argName: 'file',
            argPos: 1,
            valueHelp: 'dest',
            mandatory: true,
          ),
          StringOption(argName: 'target'),
          FlagOption(argName: 'color', hideNegatedUsage: true),
          FlagOption(argName: 'force', negatable: false, mandatory: true),
          MultiStringOption(argName: 'include', valueHelp: 'path'),
          MultiStringOption(argName: 'tag', mandatory: true),
          StringOption(argName: 'secret', hide: true),
          StringOption(envName: 'COPY_MODE'),
        ],
      );
      _runner(subcommands: [command]);
    });

    test(
      'when reading usage then the synopsis orders positionals before names',
      () {
        expect(
          command.usage,
          contains(
            'Usage: tool copy <file> <dest> [--verbose] [--target=<target>] '
            '[--color] --force [--include=<path>]... --tag=<tag>...',
          ),
        );
      },
    );
  });

  group('Given a mandatory exclusive group', () {
    late Command<OptionDefinition, void> command;

    setUp(() {
      const format = MutuallyExclusive(
        'format',
        mode: MutuallyExclusiveMode.mandatory,
      );
      const input = MutuallyExclusive(
        'input',
        mode: MutuallyExclusiveMode.mandatory,
      );
      command = _command(
        name: 'render',
        description: 'Render',
        persistentOptions: const [
          StringOption(argName: 'stdin', group: input),
        ],
        options: const [
          StringOption(argPos: 0, valueHelp: 'file', group: input),
          StringOption(argPos: 1, valueHelp: 'dest', mandatory: true),
          FlagOption(argName: 'verbose', negatable: false),
          StringOption(argName: 'json', group: format),
          StringOption(argName: 'text', valueHelp: 'file', group: format),
        ],
      );
      _runner(subcommands: [command]);
    });

    test(
      'when reading usage then the group is one required choice',
      () {
        expect(
          command.usage,
          contains(
            'Usage: tool render (<file> | --stdin=<stdin>) <dest> [--verbose] '
            '(--json=<json> | --text=<file>)',
          ),
        );
      },
    );
  });

  group('Given an optional exclusive group', () {
    late Command<OptionDefinition, void> command;

    setUp(() {
      const format = MutuallyExclusive('format');
      command = _command(
        name: 'render',
        description: 'Render',
        options: const [
          FlagOption(argName: 'json', negatable: false, group: format),
          FlagOption(argName: 'text', negatable: false, group: format),
        ],
      );
      _runner(subcommands: [command]);
    });

    test(
      'when reading usage then the group is one optional choice',
      () {
        expect(
          command.usage,
          contains('Usage: tool render [--json | --text]'),
        );
      },
    );
  });

  group('Given a runner with long usage text', () {
    late CommandRunner<OptionDefinition, void> runner;

    setUp(() {
      runner = _longUsageRunner();
    });

    test('when reading usage then the text is not wrapped', () {
      expect(
        runner.usage,
        _usage(const [
          'A command line tool that builds and deploys applications.',
          '',
          'Usage: tool [global-options] <command> [arguments]',
          '',
          'Global options:',
          '--verbose     Print extra information while the command is running.',
          '-h, --help    Show the usage help for a command.',
          '              (defaults to false)',
          '',
          'Available commands:',
          '  build   Build the application from the current sources.',
          '',
          'Run "tool help <command>" for more information about a command.',
          '',
          'See the documentation for more details about this tool.',
        ]),
      );
    });
  });

  group('Given a runner with a usage line length', () {
    late CommandRunner<OptionDefinition, void> runner;

    setUp(() {
      runner = _longUsageRunner(usageLineLength: 40);
    });

    test('when reading usage then the text is wrapped to that length', () {
      expect(
        runner.usage,
        _usage(const [
          'A command line tool that builds and',
          'deploys applications.',
          '',
          'Usage: tool [global-options] <command>',
          '       [arguments]',
          '',
          'Global options:',
          '--verbose     Print extra information',
          '              while the command is',
          '              running.',
          '-h, --help    Show the usage help for a',
          '              command.',
          '              (defaults to false)',
          '',
          'Available commands:',
          '  build   Build the application from the',
          '          current sources.',
          '',
          'Run "tool help <command>" for more',
          'information about a command.',
          '',
          'See the documentation for more details',
          'about this tool.',
        ]),
      );
    });
  });

  group('Given a subcommand of a runner with a usage line length', () {
    late Command<OptionDefinition, void> command;

    setUp(() {
      final runner = _longUsageRunner(usageLineLength: 40);
      command = runner.subcommands.firstWhere(
        (final subcommand) => subcommand.name == 'build',
      );
    });

    test(
      'when reading usage then the text is wrapped to the runner length',
      () {
        expect(
          command.usage,
          _usage(const [
            'Build the application from the current',
            'sources.',
            '',
            'Usage: tool build [--release]',
            '',
            'Options:',
            '--release    Compile with optimizations',
            '             for a production release.',
            '',
            'Run "tool help" to see global options.',
          ]),
        );
      },
    );
  });

  group('Given a usage line length shorter than ten columns', () {
    late CommandRunner<OptionDefinition, void> runner;

    setUp(() {
      runner = _runner(
        description: 'abcdefghijabcdefghijab',
        usageLineLength: 1,
      );
    });

    test(
      'when reading usage then a long word is split every ten characters',
      () {
        expect(
          runner.usage,
          startsWith('abcdefghij\nabcdefghij\nab\n\n'),
        );
      },
    );
  });

  group('Given a command that can run as a leaf and has a subcommand', () {
    late Command<OptionDefinition, void> command;

    setUp(() {
      command = _command(
        name: 'build',
        description: 'Build',
        canRunAsLeafCommand: true,
        options: const [
          FlagOption(argName: 'force', negatable: false),
        ],
        subcommands: [
          _command(name: 'version', description: 'Show the version'),
        ],
      );
      _runner(subcommands: [command]);
    });

    test(
      'when reading usage then the synopsis has a leaf alternative',
      () {
        expect(
          command.usage,
          contains(
            'Usage: tool build [--force] <subcommand> [arguments]\n'
            '   or: tool build [--force]\n',
          ),
        );
      },
    );
  });
}

Command<OptionDefinition, void> _command({
  required final String name,
  required final String description,
  final List<String>? aliases,
  final bool? hidden,
  final bool canRunAsLeafCommand = false,
  final List<OptionDefinition>? persistentOptions,
  final List<OptionDefinition>? options,
  final List<Command<OptionDefinition, void>>? subcommands,
}) {
  return _UsageCommand(
    name: name,
    description: description,
    aliases: aliases,
    hidden: hidden,
    canRunAsLeafCommand: canRunAsLeafCommand,
    persistentOptions: persistentOptions,
    options: options,
    subcommands: subcommands,
  );
}

class _UsageCommand extends CommandImpl<OptionDefinition, void> {
  _UsageCommand({
    required super.name,
    required super.description,
    super.aliases,
    super.hidden,
    super.canRunAsLeafCommand,
    super.persistentOptions,
    super.options,
    super.subcommands,
  });

  @override
  void run(final CommandContext<OptionDefinition, void> context) {}
}

CommandRunner<OptionDefinition, void> _runner({
  final String description = 'Tools',
  final List<OptionDefinition>? globalOptions,
  final List<Command<OptionDefinition, void>>? subcommands,
  final int? usageLineLength,
  final String? rootFooter,
}) {
  return CommandRunner(
    'tool',
    description,
    globalOptions: globalOptions,
    subcommands: subcommands,
    usageLineLength: usageLineLength,
    rootFooter: rootFooter,
    // The built-in completion command is covered by the completion tests.
    completion: CompletionSettings.disabled,
  );
}

CommandRunner<OptionDefinition, void> _longUsageRunner({
  final int? usageLineLength,
}) {
  return _runner(
    description: 'A command line tool that builds and deploys applications.',
    usageLineLength: usageLineLength,
    rootFooter: 'See the documentation for more details about this tool.',
    globalOptions: const [
      FlagOption(
        argName: 'verbose',
        negatable: false,
        helpText: 'Print extra information while the command is running.',
      ),
      CommandRunnerBuiltinOptions.help,
    ],
    subcommands: [
      _command(
        name: 'build',
        description: 'Build the application from the current sources.',
        options: const [
          FlagOption(
            argName: 'release',
            negatable: false,
            helpText: 'Compile with optimizations for a production release.',
          ),
        ],
      ),
    ],
  );
}

String _usage(final Iterable<String> lines) => '${lines.join('\n')}\n';
