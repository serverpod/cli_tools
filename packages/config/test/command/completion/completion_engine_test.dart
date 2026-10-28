import 'package:config/command.dart';
import 'package:config/config.dart';
import 'package:test/test.dart';

import 'fixtures/completion_cli.dart';

/// The parsed response of a `__complete` request.
typedef Response = ({List<String> lines, int directive});

/// Runs a `__complete` request on [runner] and parses the response.
Future<Response> complete(
  final CommandRunner<OptionDefinition, int> runner,
  final StringBuffer out,
  final List<String> words, {
  final Map<String, String>? env,
}) async {
  final result = await runner.execute(['__complete', ...words], env: env);
  expect(result, isNull, reason: 'a completion request runs no command');
  final lines = out.toString().split('\n');
  expect(lines.last, isEmpty, reason: 'the response ends with a newline');
  lines.removeLast();
  final footer = lines.removeLast();
  expect(footer, startsWith(':'), reason: 'the response ends with :<N>');
  return (lines: lines, directive: int.parse(footer.substring(1)));
}

/// The candidate values of a response, without descriptions.
List<String> valuesOf(final Response response) =>
    response.lines.map((final line) => line.split('\t').first).toList();

void main() {
  late StringBuffer out;
  late StringBuffer err;
  late CommandRunner<OptionDefinition, int> runner;
  late List<String> trace;

  setUp(() {
    out = StringBuffer();
    err = StringBuffer();
    trace = [];
    runner = buildCompletionCli(
      usageOutput: UsageOutputHandler(
        sinks: UsageSinks(out: out, err: err),
      ),
      trace: trace,
    );
  });

  group('Given a completion request for the first word', () {
    test('when the word is empty then the non-hidden subcommands '
        'including the built-in completion command are offered '
        'with the first line of their description', () async {
      final response = await complete(runner, out, ['']);
      expect(response.lines, [
        'build\tBuild the project.',
        'deploy\tDeploy a bundle to a target.',
        'export\tExport data in one of the formats.',
        'version\tDisplay the version.',
        'db\tDatabase commands.',
        'completion\tGenerate a shell completion script.',
      ]);
      expect(response.directive, CompletionDirective.noFileCompletion);
    });

    test('when the word is a prefix then only matching subcommands '
        'are offered', () async {
      final response = await complete(runner, out, ['d']);
      expect(valuesOf(response), ['deploy', 'db']);
    });

    test('when the word is a dash then the global options and the '
        'option-like command aliases are offered', () async {
      final response = await complete(runner, out, ['-']);
      expect(response.lines, [
        '--config\tThe configuration file.',
        '-c\tThe configuration file.',
        '--verbose\tPrint more.',
        '--no-verbose\tPrint more.',
        '--help\tShow the usage help for a command.',
        '-h\tShow the usage help for a command.',
        '--version\tDisplay the version.',
      ]);
      expect(response.directive, CompletionDirective.noFileCompletion);
    });

    test('when the word is a double dash then short options '
        'are not offered', () async {
      final response = await complete(runner, out, ['--']);
      expect(valuesOf(response), [
        '--config',
        '--verbose',
        '--no-verbose',
        '--help',
        '--version',
      ]);
    });

    test('when the word is a long option prefix '
        'then only matching options are offered', () async {
      final response = await complete(runner, out, ['--ver']);
      expect(valuesOf(response), ['--verbose', '--version']);
    });

    test('then no command and no middleware is run', () async {
      await complete(runner, out, ['']);
      expect(trace, isEmpty);
    });

    test('then nothing is written to the error sink', () async {
      await complete(runner, out, ['']);
      expect(err.toString(), isEmpty);
    });
  });

  group('Given a completion request within a subcommand', () {
    test('when the word is a dash then the subcommand options, '
        'and the global options, but not hidden options, '
        'are offered', () async {
      final response = await complete(runner, out, ['build', '-']);
      expect(valuesOf(response), [
        '--config',
        '-c',
        '--verbose',
        '--no-verbose',
        '--help',
        '-h',
        '--mode',
        '-m',
        '--out',
        '-o',
        '--tags',
        '--jobs',
        '-j',
        '--project',
        '--env',
        '-e',
        '--spec',
      ]);
    });

    test('when an option was already given '
        'then it is no longer offered', () async {
      final response = await complete(runner, out, [
        '--verbose',
        'build',
        '--mode',
        'debug',
        '-',
      ]);
      expect(valuesOf(response), isNot(contains('--mode')));
      expect(valuesOf(response), isNot(contains('-m')));
      expect(valuesOf(response), isNot(contains('--verbose')));
      expect(valuesOf(response), contains('--out'));
    });

    test('when a multi-option was already given '
        'then it is still offered', () async {
      final response = await complete(runner, out, [
        'build',
        '--tags',
        'fast',
        '--',
      ]);
      expect(valuesOf(response), contains('--tags'));
    });

    test('when the subcommand has no positional options '
        'and the word is not an option then nothing is offered', () async {
      final response = await complete(runner, out, ['build', '']);
      expect(response.lines, isEmpty);
      expect(response.directive, CompletionDirective.noFileCompletion);
    });

    test('when the command is nested '
        'then its subcommands are offered', () async {
      final response = await complete(runner, out, ['db', '']);
      expect(response.lines, [
        'migrate\tRun the migrations.',
        'seed\tSeed the database.',
      ]);
    });

    test('when the command is nested '
        'then its options are completed', () async {
      final response = await complete(runner, out, [
        'db',
        'migrate',
        '--steps',
        '',
      ]);
      expect(valuesOf(response), ['1', '5', '10']);
    });
  });

  group('Given a completion request for an option value', () {
    test('when the option is an enum then its values are offered '
        'with allowed help descriptions', () async {
      final response = await complete(runner, out, ['build', '--mode', '']);
      expect(response.lines, [
        'debug\tDebug build',
        'profile',
        'release\tOptimized build',
      ]);
      expect(response.directive, CompletionDirective.noFileCompletion);
    });

    test('when the option is given by abbreviation '
        'then its values are offered', () async {
      final response = await complete(runner, out, ['build', '-m', '']);
      expect(valuesOf(response), ['debug', 'profile', 'release']);
    });

    test('when the value is attached with an equals sign '
        'then the bare values are offered', () async {
      final response = await complete(runner, out, ['build', '--mode=re']);
      expect(valuesOf(response), ['debug', 'profile', 'release']);
      expect(response.directive, CompletionDirective.noFileCompletion);
    });

    test('when the option is a directory option '
        'then directory completion is requested', () async {
      final response = await complete(runner, out, ['build', '--out', '']);
      expect(response.lines, isEmpty);
      expect(response.directive, CompletionDirective.filterDirectories);
    });

    test('when the option is a file option '
        'then file completion is requested', () async {
      final response = await complete(runner, out, ['--config', '']);
      expect(response.lines, isEmpty);
      expect(response.directive, CompletionDirective.defaultDirective);
    });

    test('when the option completes files with given extensions '
        'then extension filtered file completion is requested', () async {
      final response = await complete(runner, out, ['build', '--spec', '']);
      expect(response.lines, ['yaml', 'yml']);
      expect(response.directive, CompletionDirective.filterFileExtensions);
    });

    test('when the option is an int option without allowed values '
        'then file completion is requested', () async {
      final response = await complete(runner, out, ['build', '--jobs', '']);
      expect(response.lines, isEmpty);
      expect(response.directive, CompletionDirective.defaultDirective);
    });

    test('when the option is a multi-option with allowed values '
        'then the values are offered', () async {
      final response = await complete(runner, out, ['build', '--tags', '']);
      expect(valuesOf(response), ['fast', 'slow', 'net']);
    });

    test('when completing a later element of a multi-option list '
        'then the earlier elements are kept as prefix', () async {
      final response = await complete(runner, out, [
        'build',
        '--tags',
        'fast,s',
      ]);
      expect(valuesOf(response), ['fast,fast', 'fast,slow', 'fast,net']);
    });

    test('when the preceding option is a flag '
        'then the word is not treated as its value', () async {
      final response = await complete(runner, out, ['--verbose', '']);
      expect(valuesOf(response), contains('build'));
    });

    test('when the option is given twice '
        'then the values are still offered', () async {
      final response = await complete(runner, out, [
        'build',
        '--mode',
        'debug',
        '--mode',
        '',
      ]);
      expect(valuesOf(response), ['debug', 'profile', 'release']);
    });

    test('when the option is an alias '
        'then the option is still recognized', () async {
      final response = await complete(runner, out, [
        'build',
        '--proj',
        'p',
        '--env',
        '',
      ]);
      expect(valuesOf(response), ['p-dev', 'p-prod', '!']);
    });
  });

  group('Given a custom option type overriding complete', () {
    test('when completing its value then the custom candidates are '
        'offered unfiltered, with the raw values of preceding options '
        'available in the context', () async {
      final response = await complete(runner, out, [
        'build',
        '--project',
        'acme',
        '--env',
        'x',
      ]);
      expect(response.lines, [
        'acme-dev\tDevelopment',
        'acme-prod\tProduction',
        'x!\tEcho',
      ]);
    });

    test('when the preceding option is not given '
        'then the context reports it as not parsed', () async {
      final response = await complete(runner, out, ['build', '-e', '']);
      expect(valuesOf(response), ['default-dev', 'default-prod', '!']);
    });

    test('when the custom completion throws '
        'then an error response is given '
        'and the failure is reported on the error sink', () async {
      final response = await complete(runner, out, [
        'build',
        '--project',
        'boom',
        '--env',
        '',
      ]);
      expect(response.lines, isEmpty);
      expect(response.directive, CompletionDirective.error);
      expect(err.toString(), contains('Completion failed'));
      expect(err.toString(), contains('completion failure'));
    });
  });

  group('Given a completion request for positional arguments', () {
    test('when completing the first positional argument '
        'then its allowed values are offered', () async {
      final response = await complete(runner, out, ['deploy', '']);
      expect(response.lines, [
        'staging\tStaging servers',
        'production\tLive servers',
      ]);
    });

    test('when completing the second positional argument '
        'then file completion is requested for the file option', () async {
      final response = await complete(runner, out, ['deploy', 'staging', '']);
      expect(response.lines, isEmpty);
      expect(response.directive, CompletionDirective.defaultDirective);
    });

    test('when options are interleaved '
        'then the positional index is unaffected', () async {
      final response = await complete(runner, out, [
        'deploy',
        '--verbose',
        'staging',
        '-c',
        'x.yaml',
        '',
      ]);
      expect(response.directive, CompletionDirective.defaultDirective);
    });

    test('when all positional arguments are given '
        'then nothing is offered', () async {
      final response = await complete(runner, out, [
        'deploy',
        'staging',
        'b.zip',
        '',
      ]);
      expect(response.lines, isEmpty);
      expect(response.directive, CompletionDirective.noFileCompletion);
    });

    test('when all positional arguments are given '
        'and unexpected positional arguments are ignored '
        'then file completion is requested', () async {
      runner = buildCompletionCli(
        usageOutput: UsageOutputHandler(sinks: UsageSinks(out: out)),
        ignoreUnexpectedPositionalArgs: true,
      );
      final response = await complete(runner, out, [
        'deploy',
        'staging',
        'b.zip',
        '',
      ]);
      expect(response.directive, CompletionDirective.defaultDirective);
    });

    test('when completing after a double dash '
        'and unexpected positional arguments are ignored '
        'then file completion is requested', () async {
      runner = buildCompletionCli(
        usageOutput: UsageOutputHandler(sinks: UsageSinks(out: out)),
        ignoreUnexpectedPositionalArgs: true,
      );
      final response = await complete(runner, out, ['build', '--', '-']);
      expect(response.lines, isEmpty);
      expect(response.directive, CompletionDirective.defaultDirective);
    });
  });

  group('Given a completion request with usage errors so far', () {
    test('when an unknown option precedes the word '
        'then completion still works', () async {
      final response = await complete(runner, out, [
        '--bogus',
        'build',
        '--mode',
        '',
      ]);
      expect(valuesOf(response), ['debug', 'profile', 'release']);
    });

    test('when an unknown subcommand precedes the word '
        'then nothing is offered', () async {
      final response = await complete(runner, out, ['bogus', '']);
      expect(response.lines, isEmpty);
      expect(response.directive, CompletionDirective.noFileCompletion);
    });

    test('when there are no words at all '
        'then it is treated as an empty first word', () async {
      final response = await complete(runner, out, []);
      expect(valuesOf(response), contains('build'));
    });
  });

  group('Given a completion request for the built-in commands', () {
    test('when completing the completion command argument '
        'then the shell names are offered', () async {
      final response = await complete(runner, out, ['completion', '']);
      expect(valuesOf(response), [
        'bash',
        'zsh',
        'fish',
        'powershell',
        'carapace',
      ]);
    });

    test('when completing the help command argument '
        'then the non-hidden commands are offered', () async {
      final response = await complete(runner, out, ['help', '']);
      expect(valuesOf(response), [
        'build',
        'deploy',
        'export',
        'version',
        'db',
        'completion',
      ]);
    });
  });

  group('Given options in mutually exclusive groups', () {
    test('when none of the group is given '
        'then all options of the group are offered', () async {
      final response = await complete(runner, out, ['export', '-']);
      expect(
        valuesOf(response),
        containsAll(['--json', '--yaml', '--stdin']),
      );
    });

    test('when an option of the group is given '
        'then the other options of the group are no longer offered '
        'while other groups are unaffected', () async {
      final response = await complete(runner, out, ['export', '--json', '-']);
      expect(valuesOf(response), isNot(contains('--json')));
      expect(valuesOf(response), isNot(contains('--yaml')));
      expect(valuesOf(response), contains('--stdin'));
    });

    test('when a positional option is in the group '
        'and no other option of the group is given '
        'then the positional argument is completed', () async {
      final response = await complete(runner, out, ['export', '--yaml', '']);
      expect(response.directive, CompletionDirective.defaultDirective);
    });

    test('when a positional option is in the group '
        'and another option of the group is given '
        'then the positional argument is not completed', () async {
      final response = await complete(runner, out, ['export', '--stdin', '']);
      expect(response.lines, isEmpty);
      expect(response.directive, CompletionDirective.noFileCompletion);
    });

    test('when the positional option of the group is given '
        'then the other options of the group are no longer offered', () async {
      final response = await complete(runner, out, ['export', 'in.txt', '-']);
      expect(valuesOf(response), isNot(contains('--stdin')));
      expect(valuesOf(response), contains('--json'));
    });
  });

  group('Given a tool without subcommands', () {
    setUp(() {
      runner = buildLeafCompletionCli(
        usageOutput: UsageOutputHandler(
          sinks: UsageSinks(out: out, err: err),
        ),
      );
    });

    test('when completing the first word '
        'then the positional values are offered', () async {
      final response = await complete(runner, out, ['']);
      expect(valuesOf(response), ['staging', 'production']);
    });

    test('when completing a dash then the options, including the '
        'named positional options, are offered '
        'and there is no completion command', () async {
      final response = await complete(runner, out, ['-']);
      expect(valuesOf(response), [
        '--mode',
        '-m',
        '--help',
        '-h',
        '--target',
        '--bundle',
      ]);
    });
  });

  group('Given a CompletionEngine used directly', () {
    test('when completing then a response object is returned', () async {
      final engine = CompletionEngine(runner);
      final response = await engine.complete(['build', '--mode', 'd']);
      expect(response.candidates.map((final c) => c.value), [
        'debug',
        'profile',
        'release',
      ]);
      expect(response.directive, CompletionDirective.noFileCompletion);
      expect(response.allowsFileCompletion, isFalse);
    });

    test('when the environment is given '
        'then it is passed on to the completion context', () async {
      final seen = <String, String>{};
      final probe = CommandImpl.withRunFunction<OptionDefinition, int>(
        name: 'probe',
        description: 'Probe.',
        options: [_ProbeOption(seen)],
        run: (final _) => 0,
      );
      runner = buildCompletionCli(extraCommands: [probe]);
      final engine = CompletionEngine(runner);
      await engine.complete(
        ['probe', '--probe', ''],
        environment: {'HOME': '/home/x'},
      );
      expect(seen, {'HOME': '/home/x'});
    });

    test('when the completion fails then the error is reported '
        'to the callback', () async {
      Object? reported;
      final engine = CompletionEngine(
        runner,
        onError: (final error, final _) => reported = error,
      );
      final response = await engine.complete([
        'build',
        '--project',
        'boom',
        '--env',
        '',
      ]);
      expect(response.directive, CompletionDirective.error);
      expect(reported, isA<StateError>());
    });
  });

  group('Given a CompletionResponse', () {
    test('when formatted then tabs and newlines in candidates '
        'are replaced', () {
      const response = CompletionResponse(
        [CompletionCandidate('a\tb', description: 'line1\nline2')],
        directive: CompletionDirective.noFileCompletion,
      );
      expect(response.format(), 'a b\tline1 line2\n:4\n');
    });

    test('when formatted with an empty description '
        'then no tab is written', () {
      const response = CompletionResponse(
        [CompletionCandidate('a', description: '')],
        directive: CompletionDirective.defaultDirective,
      );
      expect(response.format(), 'a\n:0\n');
    });

    test('when created from a no-space result '
        'then the no-space directive is combined', () {
      final response = CompletionResponse.fromResult(
        CompletionResult.strings(['host:'], noSpace: true),
      );
      expect(
        response.directive,
        CompletionDirective.noFileCompletion | CompletionDirective.noSpace,
      );
    });

    test('when created from a file extensions result '
        'then the extensions are the candidates', () {
      final response = CompletionResponse.fromResult(
        const CompletionResult.files(extensions: ['yaml', 'yml']),
      );
      expect(response.candidates.map((final c) => c.value), ['yaml', 'yml']);
      expect(response.directive, CompletionDirective.filterFileExtensions);
      expect(response.allowsFileCompletion, isTrue);
    });
  });
}

class _ProbeOption extends StringOption {
  final Map<String, String> seen;

  const _ProbeOption(this.seen) : super(argName: 'probe');

  @override
  CompletionResult complete(final CompletionContext context) {
    seen.addAll(context.environment);
    expect(context.command.name, 'probe');
    expect(context.commands.first.name, 'comptool');
    expect(context.precedingWords, ['probe', '--probe']);
    expect(context.wordToComplete, '');
    return const CompletionResult.none();
  }
}
