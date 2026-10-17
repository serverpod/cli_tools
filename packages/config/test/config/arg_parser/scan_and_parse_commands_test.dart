import 'package:config/config.dart';
import 'package:config/src/config/arg_parser/arg_parser.dart';
import 'package:config/src/config/arg_parser/arg_scanner.dart';
import 'package:test/test.dart';

import 'arg_parser_test_support.dart';

void main() {
  group('Given a command with no subcommands', () {
    const name = StringOption(argName: 'name', argAbbrev: 'n');
    final command = TestCommand(
      name: 'tool',
      options: [name],
      usage: const CommandUsageDefinition(description: 'tool usage'),
    );

    ArgParseResult parse(final List<String> args) {
      return scanAndParseCommands(args, rootCommand: command);
    }

    test('when no arguments are parsed then the result is that command', () {
      expect(parse(<String>[]).command, same(command));
    });

    test('when no arguments are parsed then there is no child', () {
      expect(parse(<String>[]).child, isNull);
    });

    test('when no arguments are parsed then toList is that result alone', () {
      final result = parse(<String>[]);

      expect(result.toList(), [result]);
    });

    test('when words are parsed then they stay positional in order', () {
      expect(parse(['a', '', 'c']).positionalWords, ['a', '', 'c']);
    });

    test('when an option is parsed then its value is recorded', () {
      expect(parse(['--name', 'ada']).regularOptions[name], 'ada');
    });

    group('when an option is followed by a positional word', () {
      late ArgParseResult result;

      setUp(() {
        result = parse(['-n', 'ada', 'file']);
      });

      test('then the option value is not positional', () {
        expect(result.regularOptions[name], 'ada');
      });

      test('then the remaining word is positional', () {
        expect(result.positionalWords, ['file']);
      });
    });

    test('when -- is parsed then the error is recorded', () {
      expect(parse(['--']).errors, ['Unexpected value: --']);
    });

    test('when an unknown option is parsed then the error is recorded', () {
      expect(parse(['--missing']).errors, ['Unknown option: --missing']);
    });
  });

  group('Given a command tree with persistent and local options', () {
    const verbose = FlagOption(argName: 'verbose', argAbbrev: 'v');
    const force = FlagOption(argName: 'force', argAbbrev: 'f');
    const rootOnly = StringOption(argName: 'root-only');
    const midOnly = StringOption(argName: 'mid-only');
    const output = StringOption(argName: 'output', argAbbrev: 'o');

    final leaf = TestCommand(
      name: 'leaf',
      aliases: const CommandAliasesDefinition(
        aliases: ['lf', 'leaf-alias'],
        suggestionAliases: ['leave'],
      ),
      options: [output],
      usage: const CommandUsageDefinition(description: 'leaf usage'),
    );
    final mid = TestCommand(
      name: 'mid',
      aliases: const CommandAliasesDefinition(aliases: ['m']),
      options: [midOnly],
      persistentOptions: [force],
      subcommands: [leaf],
      canRunAsLeafCommand: true,
      usage: const CommandUsageDefinition(description: 'mid usage'),
    );
    final root = TestCommand(
      name: 'tool',
      options: [rootOnly],
      persistentOptions: [verbose],
      subcommands: [mid],
      usage: const CommandUsageDefinition(description: 'root usage'),
    );

    ArgParseResult parse(final List<String> args) {
      return scanAndParseCommands(args, rootCommand: root);
    }

    group('when every level receives options and the leaf has words', () {
      late ArgParseResult result;
      late ArgParseResult midResult;
      late ArgParseResult leafResult;

      setUp(() {
        result = parse([
          '--root-only',
          'r',
          '-v',
          'mid',
          '--mid-only',
          'm',
          '--force',
          'leaf',
          '--output',
          'o',
          'p1',
          'p2',
        ]);
        midResult = childResult(result);
        leafResult = childResult(midResult);
      });

      test('then toList walks from the root to the leaf', () {
        expect(
          result.toList().map((final node) => node.command).toList(),
          [root, mid, leaf],
        );
      });

      test('then the root has no parent', () {
        expect(result.parent, isNull);
      });

      test('then the mid result points at the root', () {
        expect(midResult.parent, same(result));
      });

      test('then the leaf result points at mid', () {
        expect(leafResult.parent, same(midResult));
      });

      test('then the root command recorded its own option', () {
        expect(result.regularOptions[rootOnly], 'r');
      });

      test('then the root command recorded the leading flag', () {
        expect(result.flagOptions[verbose], isTrue);
      });

      test('then the root command has no positional words', () {
        expect(result.positionalWords, isEmpty);
      });

      test('then the mid command recorded its own option', () {
        expect(midResult.regularOptions[midOnly], 'm');
      });

      test('then the mid command recorded its persistent flag', () {
        expect(midResult.flagOptions[force], isTrue);
      });

      test('then the leaf command recorded its option', () {
        expect(leafResult.regularOptions[output], 'o');
      });

      test('then the leaf command keeps the remaining words', () {
        expect(leafResult.positionalWords, ['p1', 'p2']);
      });

      test('then the subcommand token is not positional', () {
        expect(midResult.positionalWords, isEmpty);
      });
    });

    test('when toList starts at the mid command then the root is omitted', () {
      final result = parse(['mid', 'leaf']);

      expect(
        childResult(result).toList().map((final node) => node.command).toList(),
        [mid, leaf],
      );
    });

    test('when subcommands are selected by alias '
        'then the same commands run', () {
      final result = parse(['m', 'leaf-alias']);

      expect(
        result.toList().map((final node) => node.command).toList(),
        [root, mid, leaf],
      );
    });

    test('when the second leaf alias is used then the leaf runs', () {
      final result = parse(['mid', 'lf']);

      expect(childResult(childResult(result)).command, same(leaf));
    });

    test('when a suggestion alias is used then the error is recorded', () {
      expect(
        childResult(parse(['mid', 'leave'])).errors,
        ['Unknown subcommand: leave'],
      );
    });

    test('when the first word is unknown then the error is on the root', () {
      expect(parse(['nope']).errors, ['Unknown subcommand: nope']);
    });

    test('when a nested word is unknown then the error is on that command', () {
      expect(
        childResult(parse(['mid', 'nope'])).errors,
        ['Unknown subcommand: nope'],
      );
    });

    test('when the root command name is used then the error is recorded', () {
      expect(parse(['tool']).errors, ['Unknown subcommand: tool']);
    });

    test('when the first word is empty then the error is recorded', () {
      expect(parse(['']).errors, ['Unknown subcommand: ']);
    });

    test('when a branch command receives a positional word '
        'then the error is recorded', () {
      expect(
        childResult(parse(['mid', 'file'])).errors,
        ['Unknown subcommand: file'],
      );
    });

    test('when the leaf command is repeated '
        'then the second word is positional', () {
      final result = parse(['mid', 'leaf', 'leaf']);

      expect(childResult(childResult(result)).positionalWords, ['leaf']);
    });

    test('when mid is repeated under itself then the error is recorded', () {
      expect(
        childResult(parse(['mid', 'mid'])).errors,
        ['Unknown subcommand: mid'],
      );
    });

    test(
      'when a persistent flag is repeated after a subcommand '
      'then the error is on that command',
      () {
        expect(
          childResult(parse(['--verbose', 'mid', '--verbose'])).errors,
          ['Option --verbose cannot be specified more than once'],
        );
      },
    );

    test('when a persistent flag is repeated on the root '
        'then the error is recorded and the subcommand is still parsed', () {
      final result = parse(['--verbose', '--verbose', 'mid']);

      expect(result.errors, [
        'Option --verbose cannot be specified more than once',
      ]);
      expect(childResult(result).command, same(mid));
    });

    group('when a root persistent flag is passed after mid', () {
      late ArgParseResult result;

      setUp(() {
        result = parse(['mid', '--verbose']);
      });

      test('then the root records the flag', () {
        expect(result.flagOptions[verbose], isTrue);
      });

      test('then the mid command does not record the flag', () {
        expect(childResult(result).flagOptions[verbose], isNull);
      });
    });

    group('when a root persistent flag is negated after mid', () {
      late ArgParseResult result;

      setUp(() {
        result = parse(['mid', '--no-verbose']);
      });

      test('then the root records the flag as false', () {
        expect(result.flagOptions[verbose], isFalse);
      });

      test('then the mid command does not record the flag', () {
        expect(childResult(result).flagOptions[verbose], isNull);
      });
    });

    group('when a root persistent flag is passed on the leaf', () {
      late ArgParseResult result;

      setUp(() {
        result = parse(['mid', 'leaf', '-v']);
      });

      test('then the root records the flag', () {
        expect(result.flagOptions[verbose], isTrue);
      });

      test('then the mid command does not record the flag', () {
        expect(childResult(result).flagOptions[verbose], isNull);
      });

      test('then the leaf command does not record the flag', () {
        expect(childResult(childResult(result)).flagOptions[verbose], isNull);
      });
    });

    group('when a mid persistent flag is passed on the leaf', () {
      late ArgParseResult result;

      setUp(() {
        result = parse(['mid', 'leaf', '--force']);
      });

      test('then the mid command records the flag', () {
        expect(childResult(result).flagOptions[force], isTrue);
      });

      test('then the root command does not record the flag', () {
        expect(result.flagOptions[force], isNull);
      });

      test('then the leaf command does not record the flag', () {
        expect(childResult(childResult(result)).flagOptions[force], isNull);
      });
    });

    test('when force is passed on mid then mid records it', () {
      final result = parse(['mid', '-f']);

      expect(childResult(result).flagOptions[force], isTrue);
    });

    test('when force is passed before mid then the error is on the root', () {
      final result = parse(['-f', 'mid']);

      expect(result.errors, ['Unknown option: -f']);
      expect(childResult(result).command, same(mid));
    });

    test('when the leaf abbreviation is used on mid '
        'then that option and the following word are recorded', () {
      expect(childResult(parse(['mid', '-o', 'x'])).errors, [
        'Unknown option: -o',
        'Unknown subcommand: x',
      ]);
    });

    test('when a root-only option is passed after mid '
        'then that option and its value word are recorded', () {
      expect(childResult(parse(['mid', '--root-only', 'r'])).errors, [
        'Unknown option: --root-only',
        'Unknown subcommand: r',
      ]);
    });

    test('when a mid-only option is passed on the leaf '
        'then the error is on the leaf', () {
      expect(
        childResult(
          childResult(parse(['mid', 'leaf', '--mid-only', 'm'])),
        ).errors,
        ['Unknown option: --mid-only'],
      );
    });

    test('when a leaf option is passed before mid '
        'then the option and the following word are recorded', () {
      expect(parse(['--output', 'o', 'mid']).errors, [
        'Unknown option: --output',
        'Unknown subcommand: o',
      ]);
    });

    test('when the leaf option is repeated then the error is recorded', () {
      expect(
        childResult(
          childResult(parse(['mid', 'leaf', '--output', 'a', '--output', 'b'])),
        ).errors,
        ['Option --output cannot be specified more than once'],
      );
    });

    test(
      'when the leaf option is missing a value then the error is recorded',
      () {
        expect(
          childResult(childResult(parse(['mid', 'leaf', '--output']))).errors,
          ['Missing value for option: --output'],
        );
      },
    );

    test(
      'when the leaf receives an unknown option then the error is recorded',
      () {
        expect(
          childResult(childResult(parse(['mid', 'leaf', '--nope']))).errors,
          ['Unknown option: --nope'],
        );
      },
    );

    test('when -- is parsed then both errors are recorded', () {
      expect(parse(['--']).errors, [
        'Unexpected value: --',
        'A subcommand is required under tool',
      ]);
    });
  });

  group('Given subcommands that can both answer to the same word', () {
    const buildOut = StringOption(argName: 'out');
    const otherOut = StringOption(argName: 'other');
    final build = TestCommand(name: 'build', options: [buildOut]);
    final other = TestCommand(
      name: 'other',
      aliases: const CommandAliasesDefinition(aliases: ['build']),
      options: [otherOut],
    );
    final root = TestCommand(name: 'tool', subcommands: [build, other]);

    ArgParseResult parse(final List<String> args) {
      return scanAndParseCommands(args, rootCommand: root);
    }

    test('when that word is parsed then the earlier command runs', () {
      final result = parse(['build']);

      expect(childResult(result).command, same(build));
    });

    test('when that word is parsed then the earlier command options apply', () {
      final result = parse(['build', '--out', 'a']);

      expect(childResult(result).regularOptions[buildOut], 'a');
    });

    test(
      'when that word is parsed then the later command options are unknown',
      () {
        expect(
          childResult(parse(['build', '--other', 'a'])).errors,
          ['Unknown option: --other'],
        );
      },
    );

    test('when the later command name is parsed then that command runs', () {
      final result = parse(['other']);

      expect(childResult(result).command, same(other));
    });
  });

  group(
    'Given a persistent option and a subcommand option of the same name',
    () {
      const inherited = FlagOption(
        argName: 'verbose',
        helpText: 'inherited',
      );
      const local = FlagOption(argName: 'verbose', helpText: 'local');
      final leaf = TestCommand(name: 'leaf', options: [local]);
      final root = TestCommand(
        name: 'tool',
        persistentOptions: [inherited],
        subcommands: [leaf],
      );

      test('when the command tree is parsed then parsing fails', () {
        expect(
          () => scanAndParseCommands(<String>[], rootCommand: root),
          throwsA(
            isA<OptionDefinitionError>().having(
              (final e) => e.toString(),
              'toString',
              contains('Duplicate argument name: verbose'),
            ),
          ),
        );
      });
    },
  );

  group(
    'Given a subcommand persistent option that reuses an inherited name',
    () {
      const inherited = FlagOption(
        argName: 'verbose',
        helpText: 'inherited',
      );
      const local = FlagOption(argName: 'verbose', helpText: 'local');
      final leaf = TestCommand(name: 'leaf', persistentOptions: [local]);
      final root = TestCommand(
        name: 'tool',
        persistentOptions: [inherited],
        subcommands: [leaf],
      );

      test('when the command tree is parsed then parsing fails', () {
        expect(
          () => scanAndParseCommands(<String>[], rootCommand: root),
          throwsA(
            isA<OptionDefinitionError>().having(
              (final e) => e.toString(),
              'toString',
              contains('Duplicate argument name: verbose'),
            ),
          ),
        );
      });
    },
  );

  group(
    'Given a subcommand option that reuses an inherited abbreviation',
    () {
      const inherited = FlagOption(argName: 'verbose', argAbbrev: 'v');
      const local = FlagOption(argName: 'loud', argAbbrev: 'v');
      final leaf = TestCommand(name: 'leaf', options: [local]);
      final root = TestCommand(
        name: 'tool',
        persistentOptions: [inherited],
        subcommands: [leaf],
      );

      test('when the command tree is parsed then parsing fails', () {
        expect(
          () => scanAndParseCommands(<String>[], rootCommand: root),
          throwsA(
            isA<OptionDefinitionError>().having(
              (final e) => e.toString(),
              'toString',
              contains('Duplicate argument abbreviation: v'),
            ),
          ),
        );
      });
    },
  );

  group('Given a command with two subcommands of the same name', () {
    final first = TestCommand(name: 'build');
    final second = TestCommand(name: 'build');
    final root = TestCommand(name: 'tool', subcommands: [first, second]);

    test('when the command tree is parsed then parsing fails', () {
      expect(
        () => scanAndParseCommands(<String>[], rootCommand: root),
        throwsA(
          isA<CommandDefinitionError>().having(
            (final e) => e.toString(),
            'toString',
            'Invalid definition for command `build`: '
                'Duplicate subcommand name: build for command tool',
          ),
        ),
      );
    });
  });

  group('Given a nested command with two subcommands of the same name', () {
    final first = TestCommand(name: 'leaf');
    final second = TestCommand(name: 'leaf');
    final mid = TestCommand(name: 'mid', subcommands: [first, second]);
    final root = TestCommand(name: 'tool', subcommands: [mid]);

    test('when the command tree is parsed then parsing fails', () {
      expect(
        () => scanAndParseCommands(<String>[], rootCommand: root),
        throwsA(
          isA<CommandDefinitionError>().having(
            (final e) => e.toString(),
            'toString',
            'Invalid definition for command `leaf`: '
                'Duplicate subcommand name: leaf for command mid',
          ),
        ),
      );
    });
  });

  group('Given the same command name at different levels', () {
    final leaf = TestCommand(name: 'tool');
    final root = TestCommand(name: 'tool', subcommands: [leaf]);

    test('when the leaf command is selected then parsing succeeds', () {
      expect(
        scanAndParseCommands(['tool'], rootCommand: root).command,
        same(root),
      );
    });
  });

  group('Given a command with subcommands and a positional option', () {
    const file = StringOption(argName: 'file', argPos: 0);
    final leaf = TestCommand(name: 'leaf');
    final root = TestCommand(
      name: 'tool',
      options: [file],
      subcommands: [leaf],
    );

    test('when the command tree is parsed then parsing fails', () {
      expect(
        () => scanAndParseCommands(<String>[], rootCommand: root),
        throwsA(
          isA<CommandDefinitionError>().having(
            (final e) => e.toString(),
            'toString',
            'Invalid definition for command `tool`: '
                'Cannot define positional options on a command with subcommands: option `file`.',
          ),
        ),
      );
    });
  });

  group(
    'Given a command with subcommands and a persistent positional option',
    () {
      const file = StringOption(argPos: 0);
      final leaf = TestCommand(name: 'leaf');
      final root = TestCommand(
        name: 'tool',
        persistentOptions: [file],
        subcommands: [leaf],
      );

      test('when the command tree is parsed then parsing fails', () {
        expect(
          () => scanAndParseCommands(<String>[], rootCommand: root),
          throwsA(
            isA<CommandDefinitionError>().having(
              (final e) => e.toString(),
              'toString',
              'Invalid definition for command `tool`: '
                  'Persistent options must not be positional: '
                  'positional argument 0.',
            ),
          ),
        );
      });
    },
  );

  group(
    'Given a nested command with subcommands and a positional option',
    () {
      const file = StringOption(argPos: 0);
      final leaf = TestCommand(name: 'leaf');
      final mid = TestCommand(
        name: 'mid',
        options: [file],
        subcommands: [leaf],
      );
      final root = TestCommand(name: 'tool', subcommands: [mid]);

      test('when the command tree is parsed then parsing fails', () {
        expect(
          () => scanAndParseCommands(<String>[], rootCommand: root),
          throwsA(
            isA<CommandDefinitionError>().having(
              (final e) => e.toString(),
              'toString',
              'Invalid definition for command `mid`: '
                  'Cannot define positional options on a command with subcommands: '
                  'positional argument 0.',
            ),
          ),
        );
      });
    },
  );

  group('Given a command with a persistent positional option', () {
    const file = StringOption(argName: 'file', argPos: 0);
    final root = TestCommand(name: 'tool', persistentOptions: [file]);

    test('when the command tree is parsed then parsing fails', () {
      expect(
        () => scanAndParseCommands(<String>[], rootCommand: root),
        throwsA(
          isA<CommandDefinitionError>().having(
            (final e) => e.toString(),
            'toString',
            'Invalid definition for command `tool`: '
                'Persistent options must not be positional: option `file`.',
          ),
        ),
      );
    });
  });

  group('Given a nested command with a persistent positional option', () {
    const file = StringOption(argPos: 0);
    final leaf = TestCommand(name: 'run', persistentOptions: [file]);
    final root = TestCommand(name: 'tool', subcommands: [leaf]);

    test('when the command tree is parsed then parsing fails', () {
      expect(
        () => scanAndParseCommands(<String>[], rootCommand: root),
        throwsA(
          isA<CommandDefinitionError>().having(
            (final e) => e.toString(),
            'toString',
            'Invalid definition for command `run`: '
                'Persistent options must not be positional: '
                'positional argument 0.',
          ),
        ),
      );
    });
  });

  group('Given a leaf command with a positional option', () {
    const file = StringOption(argName: 'file', argPos: 0);
    final leaf = TestCommand(name: 'run', options: [file]);
    final root = TestCommand(name: 'tool', subcommands: [leaf]);

    test('when the command tree is parsed then parsing succeeds', () {
      final result = scanAndParseCommands(
        ['run', 'main.dart'],
        rootCommand: root,
      );

      expect(childResult(result).positionalWords, ['main.dart']);
    });
  });

  group('Given an option that consumes the following word', () {
    const config = StringOption(argName: 'config');
    const output = StringOption(argName: 'output');
    final run = TestCommand(
      name: 'run',
      options: [output],
      usage: const CommandUsageDefinition(description: 'run usage'),
    );
    final root = TestCommand(
      name: 'tool',
      persistentOptions: [config],
      subcommands: [run],
      canRunAsLeafCommand: true,
      usage: const CommandUsageDefinition(description: 'root usage'),
    );

    ArgParseResult parse(final List<String> args) {
      return scanAndParseCommands(args, rootCommand: root);
    }

    group('when the following word is a subcommand name', () {
      late ArgParseResult result;

      setUp(() {
        result = parse(['--config', 'run']);
      });

      test('then that word is the option value', () {
        expect(result.regularOptions[config], 'run');
      });

      test('then no subcommand runs', () {
        expect(result.child, isNull);
      });

      test('then the word is not positional', () {
        expect(result.positionalWords, isEmpty);
      });
    });

    group('when the value is attached and the subcommand follows', () {
      late ArgParseResult result;

      setUp(() {
        result = parse(['--config=run', 'run', '--output', 'out', 'file']);
      });

      test('then the attached text is the option value', () {
        expect(result.regularOptions[config], 'run');
      });

      test('then the subcommand runs', () {
        expect(childResult(result).command, same(run));
      });

      test('then the subcommand records its own option', () {
        expect(childResult(result).regularOptions[output], 'out');
      });

      test('then the subcommand keeps the remaining word', () {
        expect(childResult(result).positionalWords, ['file']);
      });
    });

    group('when the option follows the subcommand', () {
      late ArgParseResult result;

      setUp(() {
        result = parse(['run', '--config', 'app', '--output', 'out']);
      });

      test('then the owning command records the value', () {
        expect(result.regularOptions[config], 'app');
      });

      test('then the subcommand does not record the option', () {
        expect(childResult(result).regularOptions[config], isNull);
      });

      test('then the subcommand records its own option', () {
        expect(childResult(result).regularOptions[output], 'out');
      });
    });

    test(
      'when the option is repeated after the subcommand '
      'then the error is on that subcommand',
      () {
        expect(
          childResult(parse(['--config', 'a', 'run', '--config', 'b'])).errors,
          ['Option --config cannot be specified more than once'],
        );
      },
    );
  });

  group('Given a persistent option owned by an intermediate command', () {
    const profile = StringOption(argName: 'profile');
    const output = StringOption(argName: 'output');
    final leaf = TestCommand(name: 'leaf', options: [output]);
    final mid = TestCommand(
      name: 'mid',
      persistentOptions: [profile],
      subcommands: [leaf],
    );
    final root = TestCommand(name: 'tool', subcommands: [mid]);

    group('when the option is written after the leaf and a leaf option', () {
      late ArgParseResult result;
      late ArgParseResult midResult;
      late ArgParseResult leafResult;

      setUp(() {
        result = scanAndParseCommands(
          ['mid', 'leaf', '--output', 'out', '--profile', 'ci'],
          rootCommand: root,
        );
        midResult = childResult(result);
        leafResult = childResult(midResult);
      });

      test('then the owning command records the value', () {
        expect(midResult.regularOptions[profile], 'ci');
      });

      test('then the root does not record the option', () {
        expect(result.regularOptions[profile], isNull);
      });

      test('then the leaf does not record the option', () {
        expect(leafResult.regularOptions[profile], isNull);
      });

      test('then the leaf records its own option', () {
        expect(leafResult.regularOptions[output], 'out');
      });
    });
  });

  group('Given a command tree and pass-through after --', () {
    const verbose = FlagOption(argName: 'verbose', argAbbrev: 'v');
    const config = StringOption(argName: 'config', argAbbrev: 'c');
    const output = StringOption(argName: 'output', argAbbrev: 'o');

    final leaf = TestCommand(
      name: 'leaf',
      options: [output],
      usage: const CommandUsageDefinition(description: 'leaf usage'),
    );
    final mid = TestCommand(
      name: 'mid',
      persistentOptions: [verbose],
      subcommands: [leaf],
      canRunAsLeafCommand: true,
      usage: const CommandUsageDefinition(description: 'mid usage'),
    );
    final root = TestCommand(
      name: 'tool',
      options: [config],
      subcommands: [mid],
      canRunAsLeafCommand: true,
      usage: const CommandUsageDefinition(description: 'root usage'),
    );

    const passThroughRest = ScanMode(
      doubleDashHandling: DoubleDashHandling.passThroughRest,
    );

    ArgParseResult parse(final List<String> args) {
      return scanAndParseCommands(
        args,
        rootCommand: root,
        scanMode: passThroughRest,
      );
    }

    group('when -- follows the leaf command', () {
      late ArgParseResult result;
      late ArgParseResult midResult;
      late ArgParseResult leafResult;

      setUp(() {
        result = parse([
          '--config',
          'app',
          'mid',
          '-v',
          'leaf',
          '--output',
          'out',
          'file',
          '--',
          '-v',
          'leaf',
          '--output',
          'other',
        ]);
        midResult = childResult(result);
        leafResult = childResult(midResult);
      });

      test('then the root records its option', () {
        expect(result.regularOptions[config], 'app');
      });

      test('then the mid command records its flag', () {
        expect(midResult.flagOptions[verbose], isTrue);
      });

      test('then the leaf records its option', () {
        expect(leafResult.regularOptions[output], 'out');
      });

      test('then the leaf keeps words before --', () {
        expect(leafResult.positionalWords, ['file']);
      });

      test('then the leaf keeps arguments after --', () {
        expect(leafResult.unparsedArgs, ['-v', 'leaf', '--output', 'other']);
      });

      test('then the root has no unparsed arguments', () {
        expect(result.unparsedArgs, isEmpty);
      });

      test('then the mid command has no unparsed arguments', () {
        expect(midResult.unparsedArgs, isEmpty);
      });

      test('then the leaf is the last node', () {
        expect(leafResult.child, isNull);
      });
    });

    group('when -- follows an intermediate command', () {
      late ArgParseResult result;
      late ArgParseResult midResult;

      setUp(() {
        result = parse(['mid', '--', '-v', 'leaf', 'file']);
        midResult = childResult(result);
      });

      test('then no further subcommand runs', () {
        expect(midResult.child, isNull);
      });

      test('then the intermediate command keeps the remaining arguments', () {
        expect(midResult.unparsedArgs, ['-v', 'leaf', 'file']);
      });

      test('then the root has no unparsed arguments', () {
        expect(result.unparsedArgs, isEmpty);
      });

      test('then the persistent flag after -- is not recorded', () {
        expect(midResult.flagOptions[verbose], isNull);
      });

      test('then the intermediate command has no positional words', () {
        expect(midResult.positionalWords, isEmpty);
      });
    });

    group('when -- is before any subcommand', () {
      late ArgParseResult result;

      setUp(() {
        result = parse(['--', 'mid', '-v', 'leaf']);
      });

      test('then no subcommand runs', () {
        expect(result.child, isNull);
      });

      test('then the root keeps the remaining arguments', () {
        expect(result.unparsedArgs, ['mid', '-v', 'leaf']);
      });

      test('then the root has no positional words', () {
        expect(result.positionalWords, isEmpty);
      });
    });

    group('when a leaf option takes -- as its value', () {
      late ArgParseResult result;
      late ArgParseResult midResult;
      late ArgParseResult leafResult;

      setUp(() {
        result = parse([
          'mid',
          'leaf',
          '--output',
          '--',
          '-v',
          'file',
        ]);
        midResult = childResult(result);
        leafResult = childResult(midResult);
      });

      test('then -- is the option value', () {
        expect(leafResult.regularOptions[output], '--');
      });

      test('then the persistent flag after that -- is recorded', () {
        expect(midResult.flagOptions[verbose], isTrue);
      });

      test('then the following word stays positional', () {
        expect(leafResult.positionalWords, ['file']);
      });

      test('then the root has no unparsed arguments', () {
        expect(result.unparsedArgs, isEmpty);
      });

      test('then the mid command has no unparsed arguments', () {
        expect(midResult.unparsedArgs, isEmpty);
      });

      test('then the leaf has no unparsed arguments', () {
        expect(leafResult.unparsedArgs, isEmpty);
      });
    });

    group('when a leaf option takes -- and a later -- follows', () {
      late ArgParseResult result;
      late ArgParseResult midResult;
      late ArgParseResult leafResult;

      setUp(() {
        result = parse([
          'mid',
          'leaf',
          '--output',
          '--',
          '-v',
          'file',
          '--',
          'extra',
          '--output',
          'other',
        ]);
        midResult = childResult(result);
        leafResult = childResult(midResult);
      });

      test('then the first -- is the option value', () {
        expect(leafResult.regularOptions[output], '--');
      });

      test('then the persistent flag before the later -- is recorded', () {
        expect(midResult.flagOptions[verbose], isTrue);
      });

      test('then the word before the later -- stays positional', () {
        expect(leafResult.positionalWords, ['file']);
      });

      test('then arguments after the later -- are unparsed', () {
        expect(leafResult.unparsedArgs, ['extra', '--output', 'other']);
      });

      test('then the root has no unparsed arguments', () {
        expect(result.unparsedArgs, isEmpty);
      });

      test('then the mid command has no unparsed arguments', () {
        expect(midResult.unparsedArgs, isEmpty);
      });

      test('then the leaf is the last node', () {
        expect(leafResult.child, isNull);
      });
    });

    group('when a root option takes -- as its value', () {
      late ArgParseResult result;
      late ArgParseResult midResult;
      late ArgParseResult leafResult;

      setUp(() {
        result = parse(['--config', '--', 'mid', 'leaf', 'file']);
        midResult = childResult(result);
        leafResult = childResult(midResult);
      });

      test('then -- is the option value', () {
        expect(result.regularOptions[config], '--');
      });

      test('then the subcommands run', () {
        expect(
          result.toList().map((final node) => node.command).toList(),
          [root, mid, leaf],
        );
      });

      test('then the leaf keeps the remaining word', () {
        expect(leafResult.positionalWords, ['file']);
      });

      test('then the root has no unparsed arguments', () {
        expect(result.unparsedArgs, isEmpty);
      });

      test('then the mid command has no unparsed arguments', () {
        expect(midResult.unparsedArgs, isEmpty);
      });

      test('then the leaf has no unparsed arguments', () {
        expect(leafResult.unparsedArgs, isEmpty);
      });
    });

    group('when a root option takes -- and a later -- follows', () {
      late ArgParseResult result;
      late ArgParseResult midResult;

      setUp(() {
        result = parse(['--config', '--', 'mid', '--', 'leaf', '-v']);
        midResult = childResult(result);
      });

      test('then the first -- is the option value', () {
        expect(result.regularOptions[config], '--');
      });

      test('then the later -- stops the next subcommand', () {
        expect(midResult.child, isNull);
      });

      test('then the intermediate command keeps the remaining arguments', () {
        expect(midResult.unparsedArgs, ['leaf', '-v']);
      });

      test('then the root has no unparsed arguments', () {
        expect(result.unparsedArgs, isEmpty);
      });

      test('then the persistent flag after the later -- is not recorded', () {
        expect(midResult.flagOptions[verbose], isNull);
      });
    });

    group('when -- ends the leaf command', () {
      late ArgParseResult result;
      late ArgParseResult midResult;
      late ArgParseResult leafResult;

      setUp(() {
        result = parse(['mid', 'leaf', 'file', '--']);
        midResult = childResult(result);
        leafResult = childResult(midResult);
      });

      test('then the root has no unparsed arguments', () {
        expect(result.unparsedArgs, isEmpty);
      });

      test('then the mid command has no unparsed arguments', () {
        expect(midResult.unparsedArgs, isEmpty);
      });

      test('then the leaf has no unparsed arguments', () {
        expect(leafResult.unparsedArgs, isEmpty);
      });

      test('then the word before -- stays positional', () {
        expect(leafResult.positionalWords, ['file']);
      });
    });

    group('when -- is absent', () {
      late ArgParseResult result;
      late ArgParseResult midResult;
      late ArgParseResult leafResult;

      setUp(() {
        result = parse(['mid', '-v', 'leaf', 'file']);
        midResult = childResult(result);
        leafResult = childResult(midResult);
      });

      test('then the mid command records its flag', () {
        expect(midResult.flagOptions[verbose], isTrue);
      });

      test('then the root has no unparsed arguments', () {
        expect(result.unparsedArgs, isEmpty);
      });

      test('then the mid command has no unparsed arguments', () {
        expect(midResult.unparsedArgs, isEmpty);
      });

      test('then the leaf has no unparsed arguments', () {
        expect(leafResult.unparsedArgs, isEmpty);
      });
    });

    test('when the same arguments use the default scan mode '
        'then the unexpected -- is recorded on the leaf', () {
      final result = scanAndParseCommands(
        ['mid', 'leaf', '--', 'rest'],
        rootCommand: root,
      );

      expect(childResult(childResult(result)).errors, [
        'Unexpected value: --',
      ]);
    });

    test('when the same arguments use the default scan mode '
        'then the word after -- stays positional', () {
      final result = scanAndParseCommands(
        ['mid', 'leaf', '--', 'rest'],
        rootCommand: root,
      );

      expect(childResult(childResult(result)).positionalWords, ['rest']);
    });
  });

  group('Given a command that cannot run as a leaf', () {
    const verbose = FlagOption(argName: 'verbose');
    final leaf = TestCommand(
      name: 'leaf',
      usage: const CommandUsageDefinition(description: 'leaf usage'),
    );
    final mid = TestCommand(
      name: 'mid',
      subcommands: [leaf],
      usage: const CommandUsageDefinition(description: 'mid usage'),
    );
    final root = TestCommand(
      name: 'tool',
      persistentOptions: [verbose],
      subcommands: [mid],
      usage: const CommandUsageDefinition(description: 'root usage'),
    );

    test('when no arguments are parsed then a subcommand is required', () {
      final result = scanAndParseCommands(<String>[], rootCommand: root);

      expect(result.errors, ['A subcommand is required under tool']);
    });

    test('when only an option is parsed then the option is recorded', () {
      final result = scanAndParseCommands(['--verbose'], rootCommand: root);

      expect(result.flagOptions[verbose], isTrue);
    });

    test('when only an option is parsed then a subcommand is required', () {
      final result = scanAndParseCommands(['--verbose'], rootCommand: root);

      expect(result.errors, ['A subcommand is required under tool']);
    });

    test(
      'when an intermediate command is last then a subcommand is required',
      () {
        final result = scanAndParseCommands(['mid'], rootCommand: root);

        expect(childResult(result).errors, [
          'A subcommand is required under mid',
        ]);
      },
    );

    test('when the leaf command is selected then parsing succeeds', () {
      final result = scanAndParseCommands(['mid', 'leaf'], rootCommand: root);

      expect(
        result.toList().map((final node) => node.command).toList(),
        [root, mid, leaf],
      );
    });
  });

  group('Given a command that can run as a leaf', () {
    const verbose = FlagOption(argName: 'verbose');
    final leaf = TestCommand(name: 'leaf');
    final root = TestCommand(
      name: 'tool',
      persistentOptions: [verbose],
      subcommands: [leaf],
      canRunAsLeafCommand: true,
      usage: const CommandUsageDefinition(description: 'root usage'),
    );

    test('when no arguments are parsed then that command is the result', () {
      final result = scanAndParseCommands(<String>[], rootCommand: root);

      expect(result.command, same(root));
      expect(result.child, isNull);
    });

    test('when only an option is parsed then the option is recorded', () {
      final result = scanAndParseCommands(['--verbose'], rootCommand: root);

      expect(result.flagOptions[verbose], isTrue);
      expect(result.child, isNull);
    });

    test('when a word is not a subcommand then the error is recorded', () {
      final result = scanAndParseCommands(['file'], rootCommand: root);

      expect(result.errors, ['Unknown subcommand: file']);
    });
  });

  group(
    'Given pass-through after -- and a command that cannot run as a leaf',
    () {
      final leaf = TestCommand(name: 'leaf');
      final root = TestCommand(
        name: 'tool',
        subcommands: [leaf],
        usage: const CommandUsageDefinition(description: 'root usage'),
      );

      test(
        'when -- stops before a subcommand then a subcommand is required',
        () {
          final result = scanAndParseCommands(
            ['--', 'leaf'],
            rootCommand: root,
            scanMode: const ScanMode(
              doubleDashHandling: DoubleDashHandling.passThroughRest,
            ),
          );

          expect(result.errors, ['A subcommand is required under tool']);
        },
      );

      test('when -- stops before a subcommand '
          'then the following word stays unparsed', () {
        final result = scanAndParseCommands(
          ['--', 'leaf'],
          rootCommand: root,
          scanMode: const ScanMode(
            doubleDashHandling: DoubleDashHandling.passThroughRest,
          ),
        );

        expect(result.unparsedArgs, ['leaf']);
      });
    },
  );
}
