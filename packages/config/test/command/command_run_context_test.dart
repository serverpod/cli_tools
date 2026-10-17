import 'package:config/command.dart';
import 'package:config/config.dart';
import 'package:config/middleware.dart';
import 'package:test/test.dart';

import 'command_fixtures.dart';

enum BuildOption<V extends Object> implements OptionDefinition<V> {
  target(StringOption(argName: 'target', argAbbrev: 't')),
  jobs(IntOption(argName: 'jobs', defaultsTo: 1)),
  release(FlagOption(argName: 'release', defaultsTo: false)),
  path(StringOption(argPos: 0));

  const BuildOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

enum RequiredOption<V extends Object> implements OptionDefinition<V> {
  name(StringOption(argName: 'name', mandatory: true));

  const RequiredOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

void main() {
  group('Given a build command with named, flag, and positional options', () {
    late RunCommandContext<BuildOption, void> context;

    setUp(() async {
      final command = CommandImpl.withRunFunction<BuildOption, void>(
        name: 'build',
        description: 'Build the app',
        options: BuildOption.values,
        run: (final runContext) {
          context = runContext;
        },
      );
      final runner = CommandRunner(
        'tool',
        'Tools',
        subcommands: [command],
      );
      await runner.runner([
        'build',
        '--target',
        'wasm',
        '--jobs',
        '4',
        '--release',
        'lib/main.dart',
      ]);
    });

    test('when those options are set then the named option is available', () {
      expect(context.config.optionalValue(BuildOption.target), 'wasm');
    });

    test('when those options are set then the integer option is available', () {
      expect(context.config.value(BuildOption.jobs), 4);
    });

    test('when those options are set then the flag is set', () {
      expect(context.config.value(BuildOption.release), isTrue);
    });

    test(
      'when those options are set '
      'then the positional option receives the first positional word',
      () {
        expect(context.config.optionalValue(BuildOption.path), 'lib/main.dart');
      },
    );
  });

  group('Given a build command whose options are omitted', () {
    late RunCommandContext<BuildOption, void> context;

    setUp(() async {
      final command = CommandImpl.withRunFunction<BuildOption, void>(
        name: 'build',
        description: 'Build the app',
        options: BuildOption.values,
        run: (final runContext) {
          context = runContext;
        },
      );
      final runner = CommandRunner(
        'tool',
        'Tools',
        subcommands: [command],
      );
      await runner.runner(['build']);
    });

    test('when the command runs then a default integer is available', () {
      expect(context.config.value(BuildOption.jobs), 1);
    });

    test('when the command runs then an omitted flag is false', () {
      expect(context.config.value(BuildOption.release), isFalse);
    });

    test('when the command runs then an omitted named option is null', () {
      expect(context.config.optionalValue(BuildOption.target), isNull);
    });

    test('when the command runs then an omitted positional option is null', () {
      expect(context.config.optionalValue(BuildOption.path), isNull);
    });
  });

  group('Given a build command with a positional option', () {
    late UsageException? error;
    late bool ran;

    setUp(() {
      error = null;
      ran = false;
      final command = CommandImpl.withRunFunction<BuildOption, void>(
        name: 'build',
        description: 'Build the app',
        options: BuildOption.values,
        run: (final runContext) {
          ran = true;
        },
      );
      final runner = CommandRunner(
        'tool',
        'Tools',
        usageOutput: noUsageErrorOutput,
        subcommands: [command],
      );
      try {
        runner.runner(['build', 'lib/main.dart', 'extra']);
      } on UsageException catch (e) {
        error = e;
      }
    });

    test(
      'when another positional word follows '
      'then the extra word is reported',
      () {
        expect(
          error?.message,
          "build: Unexpected positional argument(s): 'extra'",
        );
      },
    );

    test(
      'when another positional word follows '
      'then the command does not run',
      () {
        expect(ran, isFalse);
      },
    );
  });

  group('Given a command with a mandatory option', () {
    late List<String> trace;
    late UsageException? error;
    late StringBuffer err;

    setUp(() {
      trace = [];
      error = null;
      err = StringBuffer();
      final command = CommandImpl.withRunFunction<RequiredOption, void>(
        name: 'greet',
        description: 'Greet',
        options: RequiredOption.values,
        middlewares: [
          (final next) => (final context) {
            trace.add('middleware');
            return next(context);
          },
        ],
        run: (final runContext) {
          trace.add('run');
        },
      );
      final runner = CommandRunner(
        'tool',
        'Tools',
        usageOutput: UsageOutputHandler(sinks: UsageSinks(err: err)),
        subcommands: [command],
      );
      try {
        runner.runner(['greet']);
      } on UsageException catch (e) {
        error = e;
      }
    });

    test('when the option is omitted then the missing option is reported', () {
      expect(error?.message, 'greet: Option `name` is mandatory.');
    });

    test(
      'when the option is omitted '
      "then the error and that command's usage are printed",
      () {
        expect(
          err.toString(),
          'greet: Option `name` is mandatory.\n'
          '\n'
          'Command: greet\n'
          'Description: Greet\n'
          'Named options:\n'
          '  name\n',
        );
      },
    );

    test(
      'when the option is omitted '
      'then the command and its middleware do not run',
      () {
        expect(trace, isEmpty);
      },
    );
  });

  group('Given a command that is missing a mandatory option', () {
    late UsageException? error;

    setUp(() {
      error = null;
      final command = CommandImpl.withRunFunction<RequiredOption, void>(
        name: 'greet',
        description: 'Greet',
        options: RequiredOption.values,
        run: (final context) {},
      );
      final runner = CommandRunner(
        'tool',
        'Tools',
        usageOutput: noUsageErrorOutput,
        subcommands: [command],
      );
      try {
        runner.runner(['greet', '--missing']);
      } on UsageException catch (e) {
        error = e;
      }
    });

    test(
      'when the command line also has an unknown option '
      'then both problems are reported',
      () {
        expect(
          error?.message,
          'greet: Unknown option: --missing.\n'
          'greet: Option `name` is mandatory.',
        );
      },
    );
  });

  group('Given a command with two mandatory options', () {
    late UsageException? error;

    setUp(() {
      error = null;
      const name = StringOption(argName: 'name', mandatory: true);
      const target = StringOption(argName: 'target', mandatory: true);
      final command = CommandImpl.withRunFunction(
        name: 'greet',
        description: 'Greet',
        options: [name, target],
        run: (final context) {},
      );
      final runner = CommandRunner(
        'tool',
        'Tools',
        usageOutput: noUsageErrorOutput,
        subcommands: [command],
      );
      try {
        runner.runner(['greet']);
      } on UsageException catch (e) {
        error = e;
      }
    });

    test('when both options are omitted then both errors are reported', () {
      expect(
        error?.message,
        'greet: Option `name` is mandatory.\n'
        'greet: Option `target` is mandatory.',
      );
    });
  });

  group('Given mandatory options on the root and on a command', () {
    late List<String> trace;
    late UsageException? error;
    late StringBuffer err;

    setUp(() {
      trace = [];
      error = null;
      err = StringBuffer();
      const verbose = StringOption(argName: 'verbose', mandatory: true);
      const name = StringOption(argName: 'name', mandatory: true);
      final command = CommandImpl.withRunFunction<OptionDefinition, String>(
        name: 'greet',
        description: 'Greet',
        options: [name],
        middlewares: [
          (final next) => (final context) {
            trace.add('middleware');
            return next(context);
          },
        ],
        run: (final context) {
          trace.add('greet');
          return null;
        },
      );
      final runner = TracingRunner(
        trace,
        globalOptions: <OptionDefinition>[
          verbose,
          CommandRunnerBuiltinOptions.help,
        ],
        usageOutput: UsageOutputHandler(sinks: UsageSinks(err: err)),
        subcommands: [command],
      );
      try {
        runner.runner(['greet']);
      } on UsageException catch (e) {
        error = e;
      }
    });

    test(
      'when both options are omitted '
      'then both commands report their errors',
      () {
        expect(
          error?.message,
          'tool: Option `verbose` is mandatory.\n'
          'greet: Option `name` is mandatory.',
        );
      },
    );

    test('when both options are omitted then nothing runs', () {
      expect(trace, isEmpty);
    });

    test(
      'when both options are omitted '
      'then usage for the first command with errors is printed',
      () {
        expect(
          err.toString(),
          'tool: Option `verbose` is mandatory.\n'
          'greet: Option `name` is mandatory.\n'
          '\n'
          'Command: tool\n'
          'Description: Tools\n'
          'Subcommands:\n'
          '  greet\n'
          '  help\n',
        );
      },
    );
  });

  group('Given a command option added after the command is created', () {
    test(
      'when the command line sets that option '
      'then the command receives the value',
      () async {
        const target = StringOption(argName: 'target');
        final command = CommandImpl.withRunFunction(
          name: 'build',
          description: 'Build the app',
          run: (final context) => context.config.optionalValue(target),
        );
        command.addOption(target);
        final runner = CommandRunner(
          'tool',
          'Tools',
          subcommands: [command],
        );

        expect(
          await runner.runner(['build', '--target', 'wasm']),
          'wasm',
        );
      },
    );
  });

  group('Given global, parent, and leaf options', () {
    const verbose = FlagOption(argName: 'verbose', defaultsTo: false);
    const profile = StringOption(argName: 'profile');
    const target = StringOption(argName: 'target');

    late RunCommandContext<OptionDefinition, void> leaf;

    setUp(() async {
      final trace = <String>[];
      final check = RecordingCommand<OptionDefinition>(
        name: 'check',
        description: 'Check the app',
        trace: trace,
        body: (final context) {
          leaf = context;
          return 'check';
        },
      );
      final build = RecordingCommand(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        options: [target],
        subcommands: [check],
      );
      final group = RecordingCommand(
        name: 'group',
        description: 'Group of commands',
        trace: trace,
        options: [profile],
        subcommands: [build],
      );
      final runner = CommandRunner(
        'tool',
        'Tools',
        globalOptions: <OptionDefinition>[
          verbose,
          CommandRunnerBuiltinOptions.help,
        ],
        subcommands: [group],
      );
      await runner.runner([
        '--verbose',
        'group',
        '--profile',
        'app',
        'build',
        '--target',
        'wasm',
        'check',
      ]);
    });

    test(
      'when the nested command line is run '
      'then the leaf sees the parent command',
      () {
        expect(leaf.prev?.command.name, 'build');
      },
    );

    test(
      'when the nested command line is run '
      'then the leaf sees the parent option',
      () {
        expect(leaf.prev?.config.optionalValue(target), 'wasm');
      },
    );

    test(
      'when the nested command line is run '
      'then the leaf sees the grandparent command',
      () {
        expect(leaf.prev?.prev?.command.name, 'group');
      },
    );

    test(
      'when the nested command line is run '
      'then the leaf sees the grandparent option',
      () {
        expect(leaf.prev?.prev?.config.optionalValue(profile), 'app');
      },
    );

    test(
      'when the nested command line is run '
      'then the leaf sees the root command',
      () {
        expect(leaf.prev?.prev?.prev?.command.name, 'tool');
      },
    );

    test(
      'when the nested command line is run '
      'then the leaf sees the global option',
      () {
        expect(leaf.globalConfig.value(verbose), isTrue);
      },
    );

    test(
      'when the nested command line is run '
      'then a parent option is not part of the leaf configuration',
      () {
        expect(leaf.config.findOption(argName: 'target'), isNull);
      },
    );
  });

  group('Given a persistent option on a branch command', () {
    const profile = StringOption(argName: 'profile');

    late String? seenByBranch;
    late RunCommandContext? childContext;

    setUp(() async {
      seenByBranch = null;
      childContext = null;
      final trace = <String>[];
      final child = RecordingCommand<OptionDefinition>(
        name: 'check',
        description: 'Check the app',
        trace: trace,
        body: (final context) {
          childContext = context;
          return 'check';
        },
      );
      final branch = RecordingCommand(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        subcommands: [child],
        body: (final context) {
          seenByBranch = context.config.optionalValue(profile);
          return 'build';
        },
      );
      branch.addOption(profile, persistent: true);
      final runner = CommandRunner(
        'tool',
        'Tools',
        subcommands: [branch],
      );
      await runner.runner(['build', '--profile', 'ci', 'check']);
    });

    test(
      'when the option is set on the branch command '
      'then the branch command run is not invoked',
      () {
        expect(seenByBranch, isNull);
      },
    );

    test(
      'when the option is set on the branch command '
      'then the child reads it from the parent configuration',
      () {
        expect(childContext?.prev?.config.optionalValue(profile), 'ci');
      },
    );

    test(
      'when the option is set on the branch command '
      'then the child configuration does not own it',
      () {
        expect(childContext?.config.findOption(argName: 'profile'), isNull);
      },
    );
  });

  group('Given a global option written after a subcommand', () {
    const verbose = FlagOption(argName: 'verbose', defaultsTo: false);

    late RunCommandContext context;

    setUp(() async {
      final command = CommandImpl.withRunFunction<OptionDefinition, String>(
        name: 'build',
        description: 'Build the app',
        run: (final runContext) {
          context = runContext;
          return 'build';
        },
      );
      final runner = CommandRunner(
        'tool',
        'Tools',
        globalOptions: <OptionDefinition>[
          verbose,
          CommandRunnerBuiltinOptions.help,
        ],
        subcommands: [command],
      );
      await runner.runner(['build', '--verbose']);
    });

    test(
      'when the command line is run '
      'then the global configuration has the option',
      () {
        expect(context.globalConfig.value(verbose), isTrue);
      },
    );
  });

  group('Given a persistent option written after a nested command', () {
    const profile = StringOption(argName: 'profile');

    late RunCommandContext leaf;

    setUp(() async {
      final trace = <String>[];
      final check = RecordingCommand<OptionDefinition>(
        name: 'check',
        description: 'Check the app',
        trace: trace,
        body: (final context) {
          leaf = context;
          return 'check';
        },
      );
      final build = RecordingCommand(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        subcommands: [check],
      );
      final group = RecordingCommand(
        name: 'group',
        description: 'Group of commands',
        trace: trace,
        subcommands: [build],
      );
      group.addOption(profile, persistent: true);
      final runner = CommandRunner(
        'tool',
        'Tools',
        subcommands: [group],
      );
      await runner.runner([
        'group',
        'build',
        'check',
        '--profile',
        'app',
      ]);
    });

    test(
      'when the command line is run '
      'then the command that defines the option receives it',
      () {
        expect(leaf.prev?.prev?.config.optionalValue(profile), 'app');
      },
    );

    test(
      'when the command line is run '
      'then the leaf configuration does not own the option',
      () {
        expect(leaf.config.findOption(argName: 'profile'), isNull);
      },
    );

    test(
      'when the command line is run '
      'then the intermediate command does not own the option',
      () {
        expect(leaf.prev?.config.findOption(argName: 'profile'), isNull);
      },
    );
  });

  group(
    'Given a global option written on the root and again after a subcommand',
    () {
      const verbose = FlagOption(argName: 'verbose', defaultsTo: false);

      late UsageException? error;
      late bool ran;

      setUp(() {
        error = null;
        ran = false;
        final command = CommandImpl.withRunFunction(
          name: 'build',
          description: 'Build the app',
          run: (final runContext) {
            ran = true;
          },
        );
        final runner = CommandRunner(
          'tool',
          'Tools',
          globalOptions: <OptionDefinition>[
            verbose,
            CommandRunnerBuiltinOptions.help,
          ],
          usageOutput: noUsageErrorOutput,
          subcommands: [command],
        );
        try {
          runner.runner(['--verbose', 'build', '--verbose']);
        } on UsageException catch (e) {
          error = e;
        }
      });

      test(
        'when the command line is run '
        'then the repeated option is reported',
        () {
          expect(
            error?.message,
            'build: Option --verbose cannot be specified more than once.',
          );
        },
      );

      test('when the command line is run then the command does not run', () {
        expect(ran, isFalse);
      });
    },
  );

  group('Given a command option backed by an environment variable', () {
    const user = StringOption(argName: 'user', envName: 'APP_USER');

    test(
      'when run is given that variable '
      'then the command receives the environment value',
      () async {
        final command = CommandImpl.withRunFunction(
          name: 'greet',
          description: 'Greet',
          options: [user],
          run: (final context) => context.config.optionalValue(user),
        );
        final runner = CommandRunner(
          'tool',
          'Tools',
          subcommands: [command],
        );

        expect(
          await runner.runner(['greet'], env: {'APP_USER': 'ada'}),
          'ada',
        );
      },
    );
  });

  group('Given a runner with a configuration broker', () {
    const user = StringOption(argName: 'user', configKey: 'user');

    test(
      'when the broker has a value for the command option '
      'then the command receives that value',
      () async {
        final command = CommandImpl.withRunFunction(
          name: 'greet',
          description: 'Greet',
          options: [user],
          run: (final context) => context.config.optionalValue(user),
        );
        final runner = CommandRunner(
          'tool',
          'Tools',
          subcommands: [command],
          configBroker: _MapBroker({'user': 'ada'}),
        );
        expect(await runner.runner(['greet']), 'ada');
      },
    );
  });

  group('Given a standalone command under a parent command', () {
    const profile = StringOption(argName: 'profile');
    const verbose = FlagOption(argName: 'verbose', defaultsTo: false);

    late RunCommandContext standalone;

    setUp(() async {
      final trace = <String>[];
      final child = RecordingCommand<OptionDefinition>(
        name: 'version',
        description: 'Show the version',
        trace: trace,
        standalone: true,
        body: (final context) {
          standalone = context;
          return 'version';
        },
      );
      final parent = RecordingCommand(
        name: 'build',
        description: 'Build the app',
        trace: trace,
        options: [profile],
        subcommands: [child],
      );
      final runner = CommandRunner(
        'tool',
        'Tools',
        globalOptions: <OptionDefinition>[
          verbose,
          CommandRunnerBuiltinOptions.help,
        ],
        subcommands: [parent],
      );
      await runner.runner([
        '--verbose',
        'build',
        '--profile',
        'ci',
        'version',
      ]);
    });

    test(
      'when the standalone command runs '
      'then it still sees the parent option',
      () {
        expect(standalone.prev?.config.optionalValue(profile), 'ci');
      },
    );

    test(
      'when the standalone command runs '
      'then it still sees the global option',
      () {
        expect(standalone.globalConfig.value(verbose), isTrue);
      },
    );
  });

  group('Given a runner with result type Object?', () {
    test(
      'when a null-returning command runs under a runner middleware '
      'then the command runs',
      () async {
        var ran = false;
        final runner = CommandRunner<OptionDefinition, Object?>(
          'tool',
          'Tools',
          subcommands: [
            CommandImpl.withRunFunction(
              name: 'date',
              description: 'Display the current date',
              run: (final RunCommandContext runContext) {
                ran = true;
                return null;
              },
            ),
          ],
          middlewares: [const _ResultMiddleware().middleware],
        );

        await runner.runner(['date']);

        expect(ran, isTrue);
      },
    );
  });
}

/// Middleware class whose type arguments are inferred from the runner.
class _ResultMiddleware<O extends OptionDefinition, T>
    extends MiddlewareHooks<T?, RunCommandContext<O, T>> {
  const _ResultMiddleware();
}

class _MapBroker implements ConfigurationBroker {
  _MapBroker(this.values);

  final Map<String, String> values;

  @override
  String? valueOrNull(
    final String key,
    final Configuration cfg,
  ) {
    return values[key];
  }
}
