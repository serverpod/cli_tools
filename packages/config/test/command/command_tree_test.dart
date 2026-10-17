import 'package:config/command.dart';
import 'package:config/config.dart';
import 'package:test/test.dart';

void main() {
  group('Given a command runner named tool', () {
    final runner = CommandRunner(
      'tool',
      'Builds artifacts',
      footer: 'See docs',
    );

    test('when reading its name then the executable name is returned', () {
      expect(runner.name, 'tool');
    });

    test(
      'when reading the executable name '
      'then the name passed to the runner is returned',
      () {
        expect(runner.executableName, 'tool');
      },
    );

    test('when reading usage then the description is available', () {
      expect(runner.usage.description, 'Builds artifacts');
    });

    test('when reading usage then the footer is available', () {
      expect(runner.usage.usageFooter, 'See docs');
    });

    test('when reading subcommands then the list is empty', () {
      expect(runner.subcommands, isEmpty);
    });

    test('when reading canRunAsLeafCommand then it is false', () {
      expect(runner.canRunAsLeafCommand, isFalse);
    });

    test(
      'when reading global options '
      'then the built-in help flag is included',
      () {
        expect(
          runner.globalOptions.map((final option) => option.option.argName),
          ['help'],
        );
      },
    );
  });

  group('Given a runner that can run as a leaf', () {
    final runner = CommandRunner(
      'tool',
      'Tools',
      canRunAsLeafCommand: true,
    );

    test('when reading canRunAsLeafCommand then it is true', () {
      expect(runner.canRunAsLeafCommand, isTrue);
    });
  });

  group('Given a runner with a global option', () {
    const verbose = FlagOption(argName: 'verbose', defaultsTo: false);
    final runner = CommandRunner(
      'tool',
      'Tools',
      globalOptions: [verbose, CommandRunnerBuiltinOptions.help],
    );

    test(
      'when reading global options '
      'then the user option is followed by help',
      () {
        expect(
          runner.globalOptions.map((final option) => option.option.argName),
          ['verbose', 'help'],
        );
      },
    );
  });

  group('Given a runner with a build command', () {
    late Command build;
    late CommandRunner runner;

    setUp(() {
      build = CommandImpl.withRunFunction(
        name: 'build',
        description: 'Build the app',
        run: (final context) {},
      );
      runner = CommandRunner(
        'tool',
        'Tools',
        subcommands: [build],
      );
    });

    test(
      'when reading subcommands '
      'then the command is followed by help',
      () {
        expect(
          runner.subcommands.map((final command) => command.name),
          ['build', 'help'],
        );
      },
    );

    test(
      'when reading subcommands '
      'then the injected help command is hidden',
      () {
        expect(runner.subcommands.last.usage.hidden, isTrue);
      },
    );

    test(
      'when reading subcommands '
      'then the injected help command is a help command',
      () {
        expect(runner.subcommands.last, isA<HelpCommand>());
      },
    );

    test(
      'when reading the build command '
      'then it does not run standalone',
      () {
        expect(build.runStandalone, isFalse);
      },
    );

    test(
      'when reading the injected help command '
      'then it runs standalone',
      () {
        expect(runner.subcommands.last.runStandalone, isTrue);
      },
    );

    test('when another command is added then help stays last', () {
      final testCommand = CommandImpl.withRunFunction(
        name: 'test',
        description: 'Test the app',
        run: (final context) {},
      );
      runner.addSubcommand(testCommand);

      expect(
        runner.subcommands.map((final command) => command.name),
        ['build', 'test', 'help'],
      );
    });
  });

  group('Given a branch command', () {
    late Command parent;
    late Command child;

    setUp(() {
      child = CommandImpl.withRunFunction(
        name: 'check',
        description: 'Check the app',
        run: (final context) {},
      );
      parent = CommandImpl.withRunFunction(
        name: 'build',
        description: 'Build the app',
        run: (final context) {},
      );
      // ignore: deprecated_member_use_from_same_package
      parent.addSubcommand(child);
    });

    test(
      'when reading the branch subcommands '
      'then the child is followed by its own help command',
      () {
        expect(
          parent.subcommands.map((final command) => command.name),
          ['check', 'help'],
        );
      },
    );

    test(
      'when the branch is added to a runner '
      'then the runner help command is separate',
      () {
        final runner = CommandRunner(
          'tool',
          'Tools',
          subcommands: [parent],
        );

        expect(
          runner.subcommands.map((final command) => command.name),
          ['build', 'help'],
        );
      },
    );
  });

  group('Given a command that already has a help command', () {
    late Command help;

    setUp(() {
      help = CommandImpl.withRunFunction(
        name: 'help',
        description: 'Custom help',
        run: (final context) {},
      );
    });

    test('when reading subcommands then the custom help command is kept', () {
      final runner = CommandRunner(
        'tool',
        'Tools',
        subcommands: [help],
      );

      expect(runner.subcommands, hasLength(1));
      expect(identical(runner.subcommands.single, help), isTrue);
    });
  });
}
