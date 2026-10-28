/// A command line tool exercising the completion support.
///
/// Used in-process by the completion unit tests, and compiled to an
/// executable named `comptool` by the shell integration tests.
library;

import 'dart:async' show FutureOr;
import 'dart:io' show exitCode;

import 'package:config/command.dart';
import 'package:config/config.dart';

enum BuildMode { debug, profile, release }

const configOption = FileOption(
  argName: 'config',
  argAbbrev: 'c',
  helpText: 'The configuration file.',
);

const verboseOption = FlagOption(
  argName: 'verbose',
  helpText: 'Print more.\nSecond line of the help text.',
  negatable: true,
  defaultsTo: false,
);

const modeOption = EnumOption<BuildMode>(
  enumParser: EnumParser(BuildMode.values),
  argName: 'mode',
  argAbbrev: 'm',
  helpText: 'The build mode.',
  allowedHelp: {
    'debug': 'Debug build',
    'release': 'Optimized build',
  },
);

const outOption = DirOption(
  argName: 'out',
  argAbbrev: 'o',
  helpText: 'The output directory.',
);

const tagsOption = MultiStringOption(
  argName: 'tags',
  helpText: 'The tags.',
  allowedValues: ['fast', 'slow', 'net'],
);

const jobsOption = IntOption(
  argName: 'jobs',
  argAbbrev: 'j',
  helpText: 'The number of jobs.',
);

const secretOption = StringOption(
  argName: 'secret',
  helpText: 'Not shown.',
  hide: true,
);

const projectOption = StringOption(
  argName: 'project',
  argAliases: ['proj'],
  helpText: 'The project.',
);

/// A custom option type with a custom, context dependent completion list.
class EnvironmentOption extends StringOption {
  const EnvironmentOption({super.argName, super.argAbbrev, super.helpText});

  @override
  FutureOr<CompletionResult> complete(final CompletionContext context) async {
    final args = context.parsedArgs;
    final project = args.wasParsed(projectOption)
        ? args.option(projectOption)
        : 'default';
    if (project == 'boom') throw StateError('completion failure');
    await Future<void>.delayed(Duration.zero);
    return CompletionResult.values([
      CompletionCandidate('$project-dev', description: 'Development'),
      CompletionCandidate('$project-prod', description: 'Production'),
      CompletionCandidate('${context.wordToComplete}!', description: 'Echo'),
    ]);
  }
}

const envOption = EnvironmentOption(
  argName: 'env',
  argAbbrev: 'e',
  helpText: 'The environment.',
);

/// A custom file option type completing only files with given extensions.
class YamlFileOption extends FileOption {
  const YamlFileOption({super.argName, super.helpText});

  @override
  CompletionResult complete(final CompletionContext context) {
    return const CompletionResult.files(extensions: ['yaml', 'yml']);
  }
}

const specOption = YamlFileOption(
  argName: 'spec',
  helpText: 'The build specification file.',
);

const targetOption = StringOption(
  argName: 'target',
  argPos: 0,
  mandatory: true,
  helpText: 'The deployment target.',
  allowedValues: ['staging', 'production'],
  allowedHelp: {'staging': 'Staging servers', 'production': 'Live servers'},
);

const bundleOption = FileOption(
  argName: 'bundle',
  argPos: 1,
  helpText: 'The bundle to deploy.',
);

const stepsOption = IntOption(
  argName: 'steps',
  helpText: 'The number of migration steps.',
  allowedValues: [1, 5, 10],
);

const formatGroup = MutuallyExclusive(
  'Output format',
  mode: MutuallyExclusiveMode.mandatory,
);

const jsonOption = FlagOption(
  argName: 'json',
  helpText: 'Output JSON.',
  negatable: false,
  group: formatGroup,
);

const yamlOption = FlagOption(
  argName: 'yaml',
  helpText: 'Output YAML.',
  negatable: false,
  group: formatGroup,
);

const inputGroup = MutuallyExclusive('Input');

const stdinOption = FlagOption(
  argName: 'stdin',
  helpText: 'Read standard input.',
  negatable: false,
  group: inputGroup,
);

const inputOption = FileOption(
  argName: 'input',
  argPos: 0,
  helpText: 'The input file.',
  group: inputGroup,
);

/// The default settings for the in-process tests: completion output must not
/// exit the test process.
const inProcessCompletion = CompletionSettings(exitAfterResponse: false);

CommandRunner<OptionDefinition, int> buildCompletionCli({
  final UsageOutputHandler usageOutput = const UsageOutputHandler(),
  final CompletionSettings completion = inProcessCompletion,
  final bool ignoreUnexpectedPositionalArgs = false,
  final List<String>? trace,
  final List<Command<OptionDefinition, int>> extraCommands = const [],
}) {
  int? run(final CommandContext context) {
    trace?.add(context.command.name);
    return 0;
  }

  return CommandRunner<OptionDefinition, int>(
    'comptool',
    'A tool for testing command line completion.\nMore description.',
    globalOptions: [
      configOption,
      verboseOption,
      CommandRunnerBuiltinOptions.help,
    ],
    usageOutput: usageOutput,
    completion: completion,
    ignoreUnexpectedPositionalArgs: ignoreUnexpectedPositionalArgs,
    middlewares: [
      Middlewares.onBeforeRun((final ctx) {
        trace?.add('middleware:${ctx.command.name}');
      }),
    ],
    subcommands: [
      CommandImpl.withRunFunction(
        name: 'build',
        description: 'Build the project.\nIn one of the build modes.',
        options: [
          modeOption,
          outOption,
          tagsOption,
          jobsOption,
          secretOption,
          projectOption,
          envOption,
          specOption,
        ],
        run: run,
      ),
      CommandImpl.withRunFunction(
        name: 'deploy',
        description: 'Deploy a bundle to a target.',
        options: [targetOption, bundleOption],
        run: run,
      ),
      CommandImpl.withRunFunction(
        name: 'export',
        description: 'Export data in one of the formats.',
        options: [jsonOption, yamlOption, stdinOption, inputOption],
        run: run,
      ),
      CommandImpl.withRunFunction(
        name: 'internal',
        description: 'A hidden command.',
        hidden: true,
        run: run,
      ),
      CommandImpl.withRunFunction(
        name: 'version',
        aliases: ['--version'],
        description: 'Display the version.',
        run: run,
      ),
      CommandImpl.withRunFunction(
        name: 'db',
        description: 'Database commands.',
        subcommands: [
          CommandImpl.withRunFunction(
            name: 'migrate',
            description: 'Run the migrations.',
            options: [stepsOption],
            run: run,
          ),
          CommandImpl.withRunFunction(
            name: 'seed',
            description: 'Seed the database.',
            run: run,
          ),
        ],
        run: run,
      ),
      ...extraCommands,
    ],
  );
}

/// A tool without subcommands: options and positional arguments only.
CommandRunner<OptionDefinition, int> buildLeafCompletionCli({
  final UsageOutputHandler usageOutput = const UsageOutputHandler(),
  final CompletionSettings completion = inProcessCompletion,
  final bool ignoreUnexpectedPositionalArgs = false,
  final List<OptionDefinition> extraGlobalOptions = const [],
}) {
  return CommandRunner<OptionDefinition, int>(
      'leaftool',
      'A tool without subcommands.',
      globalOptions: [
        modeOption,
        CommandRunnerBuiltinOptions.help,
        ...extraGlobalOptions,
      ],
      usageOutput: usageOutput,
      completion: completion,
      canRunAsLeafCommand: true,
      ignoreUnexpectedPositionalArgs: ignoreUnexpectedPositionalArgs,
    )
    // Positional options can't be persistent, add them as regular options.
    ..addOption(targetOption)
    ..addOption(bundleOption);
}

/// Printed after the runner returns, as a program might do. With the default
/// completion settings the process exits before this for completion output.
const afterRunnerMarker = '>>> result:';

Future<void> main(final List<String> args) async {
  try {
    final result = await buildCompletionCli(
      completion: const CompletionSettings(),
    ).execute(args);
    print('$afterRunnerMarker $result');
    exitCode = result ?? 0;
  } on UsageException {
    exitCode = 64;
  }
}
