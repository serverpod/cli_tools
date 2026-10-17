import 'package:config/command.dart';
import 'package:config/config.dart';
import 'package:test/test.dart';

import 'fixtures/completion_cli.dart';

void main() {
  late StringBuffer out;
  late StringBuffer err;
  late List<String> trace;
  late CommandRunner<OptionDefinition, int> runner;

  UsageOutputHandler usage() => UsageOutputHandler(
    sinks: UsageSinks(out: out, err: err),
  );

  setUp(() {
    out = StringBuffer();
    err = StringBuffer();
    trace = [];
    runner = buildCompletionCli(usageOutput: usage(), trace: trace);
  });

  group('Given a runner with subcommands and default completion settings', () {
    test('when listing the subcommands '
        'then the completion command is included before help', () {
      expect(runner.subcommands.map((final c) => c.name), [
        'build',
        'deploy',
        'export',
        'internal',
        'version',
        'db',
        'completion',
        'help',
      ]);
    });

    test('when printing the usage '
        'then the completion command is listed', () {
      expect(runner.usage, contains('completion'));
      expect(runner.usage, contains('Generate a shell completion script.'));
    });

    for (final shell in CompletionShell.values) {
      test('when running `completion ${shell.name}` '
          'then the ${shell.displayName} script for the executable '
          'is written to the output sink and nothing else runs', () async {
        final result = await runner.execute(['completion', shell.name]);
        expect(result, isNull);
        expect(
          out.toString(),
          shell.script(
            'comptool',
            description: runner.usageDefinition.description,
          ),
        );
        expect(err.toString(), isEmpty);
        expect(trace, isEmpty, reason: 'middlewares are bypassed');
      });
    }

    test('when running `completion` without a shell '
        'then a usage error is reported', () async {
      await expectLater(
        runner.execute(['completion']),
        throwsA(isA<UsageException>()),
      );
      expect(err.toString(), contains('shell'));
    });

    test('when running `completion` with an unknown shell '
        'then a usage error listing the shells is reported', () async {
      await expectLater(
        runner.execute(['completion', 'tcsh']),
        throwsA(isA<UsageException>()),
      );
      expect(err.toString(), contains('bash'));
      expect(err.toString(), contains('carapace'));
    });

    test('when running `completion --help` '
        'then the installation instructions name the executable '
        'and are part of the description, before the usage line', () async {
      await runner.execute(['completion', '--help']);
      final output = out.toString();
      for (final shell in CompletionShell.values) {
        expect(output, contains(shell.installInstruction('comptool')));
      }
      expect(output, contains('Usage: comptool completion'));
      expect(
        output.indexOf('Installation:'),
        lessThan(output.indexOf('Usage: comptool completion')),
      );
    });

    test('when running `help completion` '
        'then its usage is printed although the shell is missing', () async {
      await runner.execute(['help', 'completion']);
      expect(out.toString(), contains('Usage: comptool completion <shell>'));
      expect(err.toString(), isEmpty);
    });

    test('when running `--completion zsh` '
        'then the Zsh script is printed as well', () async {
      await runner.execute(['--completion', 'zsh']);
      expect(out.toString(), CompletionShell.zsh.script('comptool'));
    });

    test('when running `--completion` with extra arguments '
        'then it is not treated as a script request', () async {
      await expectLater(
        runner.execute(['--completion', 'zsh', 'build']),
        throwsA(isA<UsageException>()),
      );
      expect(out.toString(), isEmpty);
    });

    test('when running a regular command '
        'then it runs as usual', () async {
      final result = await runner.execute(['build']);
      expect(result, 0);
      expect(trace, ['middleware:comptool', 'build']);
    });
  });

  group('Given a runner with completion disabled', () {
    setUp(() {
      runner = buildCompletionCli(
        usageOutput: usage(),
        completion: CompletionSettings.disabled,
        trace: trace,
      );
    });

    test('when listing the subcommands '
        'then there is no completion command', () {
      expect(runner.subcommands.map((final c) => c.name), [
        'build',
        'deploy',
        'export',
        'internal',
        'version',
        'db',
        'help',
      ]);
    });

    test('when running `completion bash` '
        'then it is an unknown subcommand', () async {
      await expectLater(
        runner.execute(['completion', 'bash']),
        throwsA(isA<UsageException>()),
      );
      expect(out.toString(), isEmpty);
    });

    test('when running `--completion bash` '
        'then it is an unknown option', () async {
      await expectLater(
        runner.execute(['--completion', 'bash']),
        throwsA(isA<UsageException>()),
      );
      expect(out.toString(), isEmpty);
    });

    test('when running `__complete` '
        'then it is an unknown subcommand', () async {
      await expectLater(
        runner.execute(['__complete', '']),
        throwsA(isA<UsageException>()),
      );
      expect(out.toString(), isEmpty);
    });
  });

  group('Given a runner with a hidden completion command', () {
    setUp(() {
      runner = buildCompletionCli(
        usageOutput: usage(),
        completion: const CompletionSettings(
          hideCommand: true,
          exitAfterResponse: false,
        ),
      );
    });

    test('when printing the usage '
        'then the completion command is not listed', () {
      expect(runner.usage, isNot(contains('Generate a shell completion')));
      expect(runner.usage, contains('build'));
    });

    test('when running `completion fish` '
        'then the script is still printed', () async {
      await runner.execute(['completion', 'fish']);
      expect(out.toString(), CompletionShell.fish.script('comptool'));
    });

    test('when completing the first word '
        'then the completion command is not offered', () async {
      await runner.execute(['__complete', '']);
      expect(out.toString(), isNot(contains('completion')));
    });
  });

  group('Given a runner defining its own completion subcommand', () {
    setUp(() {
      runner = buildCompletionCli(
        usageOutput: usage(),
        trace: trace,
        extraCommands: [
          CommandImpl.withRunFunction(
            name: 'completion',
            description: 'My own completion.',
            run: (final _) {
              trace.add('own completion');
              return 7;
            },
          ),
        ],
      );
    });

    test('when running `completion` then the own command runs', () async {
      final result = await runner.execute(['completion']);
      expect(result, 7);
      expect(trace, contains('own completion'));
    });

    test('when listing the subcommands '
        'then the completion command appears once', () {
      final names = runner.subcommands.map((final c) => c.name);
      expect(names.where((final n) => n == 'completion'), hasLength(1));
    });

    test('when running `--completion bash` '
        'then the script is still printed', () async {
      await runner.execute(['--completion', 'bash']);
      expect(out.toString(), CompletionShell.bash.script('comptool'));
    });
  });

  group('Given a runner without subcommands', () {
    setUp(() {
      runner = buildLeafCompletionCli(usageOutput: usage());
    });

    test('when listing the subcommands then there are none', () {
      expect(runner.subcommands, isEmpty);
    });

    test('when printing the usage '
        'then the completion option is not shown', () {
      expect(runner.usage, isNot(contains('completion')));
    });

    test('when running `--completion bash` '
        'then the Bash script for the executable is printed', () async {
      final result = await runner.execute(['--completion', 'bash']);
      expect(result, isNull);
      expect(out.toString(), CompletionShell.bash.script('leaftool'));
    });

    test('when running `--completion=powershell` '
        'then the PowerShell script is printed', () async {
      await runner.execute(['--completion=powershell']);
      expect(out.toString(), CompletionShell.powershell.script('leaftool'));
    });

    test('when running `--completion` without a shell '
        'then a usage error listing the shells is reported', () async {
      await expectLater(
        runner.execute(['--completion']),
        throwsA(
          isA<UsageException>().having(
            (final e) => e.message,
            'message',
            allOf(contains('Missing shell'), contains('bash')),
          ),
        ),
      );
      expect(err.toString(), contains('Missing shell for --completion'));
    });

    test('when running `--completion=` with an empty shell '
        'then a usage error listing the shells is reported', () async {
      await expectLater(
        runner.execute(['--completion=']),
        throwsA(
          isA<UsageException>().having(
            (final e) => e.message,
            'message',
            allOf(contains('Missing shell'), contains('bash')),
          ),
        ),
      );
    });

    test('when running `--completion` with an unknown shell '
        'then a usage error is reported', () async {
      await expectLater(
        runner.execute(['--completion', 'ksh']),
        throwsA(
          isA<UsageException>().having(
            (final e) => e.message,
            'message',
            contains('Unknown shell "ksh"'),
          ),
        ),
      );
    });

    test(
      'when running `--completion` with a shell in the wrong case '
      'then a usage error is reported since names are case sensitive',
      () async {
        await expectLater(
          runner.execute(['--completion', 'Bash']),
          throwsA(
            isA<UsageException>().having(
              (final e) => e.message,
              'message',
              contains('Unknown shell "Bash"'),
            ),
          ),
        );
      },
    );

    test('when `--completion <shell>` is followed by more arguments '
        'then it is not a script request but a regular command line', () async {
      await expectLater(
        runner.execute(['--completion', 'bash', 'extra']),
        throwsA(
          isA<UsageException>().having(
            (final e) => e.message,
            'message',
            contains('Unknown option: --completion'),
          ),
        ),
      );
      expect(out.toString(), isEmpty);
    });

    test('when `--completion <shell>` is preceded by other arguments '
        'then it is not a script request but a regular command line', () async {
      await expectLater(
        runner.execute(['--mode', 'debug', '--completion', 'bash']),
        throwsA(
          isA<UsageException>().having(
            (final e) => e.message,
            'message',
            contains('Unknown option: --completion'),
          ),
        ),
      );
      expect(out.toString(), isEmpty);
    });

    test('when running `__complete` then the request is served', () async {
      await runner.execute(['__complete', '--mode', '']);
      expect(
        out.toString(),
        'debug\tDebug build\nprofile\n'
        'release\tOptimized build\n:4\n',
      );
    });
  });

  group('Given a runner without subcommands '
      'defining its own completion option', () {
    setUp(() {
      runner = buildLeafCompletionCli(
        usageOutput: usage(),
        extraGlobalOptions: const [
          StringOption(argName: 'completion', helpText: 'Mine.'),
        ],
      );
    });

    test('when running `--completion bash` '
        'then the own option is parsed instead', () async {
      final result = await runner.execute(['--completion', 'bash', 'staging']);
      expect(result, isNull);
      expect(out.toString(), isEmpty);
    });
  });

  group('Given the completion settings', () {
    test('when created with defaults then completion is enabled, '
        'the command is visible and the process exits after '
        'completion output', () {
      const settings = CompletionSettings();
      expect(settings.enabled, isTrue);
      expect(settings.hideCommand, isFalse);
      expect(settings.exitAfterResponse, isTrue);
    });

    test('when disabled then completion is not enabled', () {
      expect(CompletionSettings.disabled.enabled, isFalse);
    });
  });

  group('Given the completion shells', () {
    test('when creating a shell identifier '
        'then only letters, digits and underscores remain', () {
      expect(shellIdentifier('my-tool'), 'my_tool');
      expect(shellIdentifier('my.tool'), 'my_tool');
      expect(shellIdentifier('1tool'), '_1tool');
      expect(shellIdentifier(''), '_');
      expect(shellIdentifier('tool'), 'tool');
    });

    for (final shell in CompletionShell.values) {
      test('when generating the ${shell.displayName} script '
          'then it mentions the executable and the request command', () {
        final script = shell.script('my-tool', description: 'My tool.');
        expect(script, contains('my-tool'));
        expect(script, contains('__complete'));
      });

      test('when generating the ${shell.displayName} install instructions '
          'then the long form contains the install command '
          'and the short form adds the location', () {
        final command = shell.installCommand('my-tool');
        expect(command, contains('my-tool completion ${shell.name}'));
        expect(shell.installInstructions('my-tool'), contains(command));
        final short = shell.installInstruction('my-tool');
        expect(short, startsWith(command));
        final location = shell.installLocation;
        if (location != null) expect(short, endsWith('# in $location'));
      });
    }

    test('when generating the installation overview '
        'then every shell has one line', () {
      final lines = completionInstallationOverview('my-tool').split('\n');
      expect(lines.first, 'Installation:');
      expect(lines.skip(1), hasLength(CompletionShell.values.length));
      for (final shell in CompletionShell.values) {
        expect(
          lines,
          contains(
            allOf(
              startsWith('  ${shell.displayName}:'),
              endsWith(shell.installInstruction('my-tool')),
            ),
          ),
        );
      }
    });
  });

  group('Given the Bash completion script', () {
    final script = CompletionShell.bash.script('my-tool');

    test('then it registers a completion function for the executable', () {
      expect(script, contains('complete -F __my_tool_complete my-tool'));
    });

    test('then compopt is guarded for old Bash versions', () {
      expect(script, contains('type compopt'));
    });

    test('then it handles all directives', () {
      expect(script, contains('directiveError=1'));
      expect(script, contains('directiveNoSpace=2'));
      expect(script, contains('directiveNoFiles=4'));
      expect(script, contains('directiveFileExt=8'));
      expect(script, contains('directiveDirs=16'));
      expect(script, contains('directiveKeepOrder=32'));
    });
  });

  group('Given the Zsh completion script', () {
    final script = CompletionShell.zsh.script('my-tool');

    test('then it is an autoloadable compdef file', () {
      expect(script, startsWith('#compdef my-tool'));
      expect(script, contains('compdef _my-tool my-tool'));
    });

    test('then it also works when sourced directly', () {
      expect(script, contains(r'$funcstack[1]'));
    });

    test('then it uses the standard completion helpers', () {
      expect(script, contains('_describe'));
      expect(script, contains('_files'));
    });
  });

  group('Given the Fish completion script', () {
    final script = CompletionShell.fish.script('my-tool');

    test('then it registers a completion for the executable', () {
      expect(
        script,
        contains("complete -c my-tool -f -a '(__my_tool_complete)'"),
      );
    });

    test('then it clears previous completions first', () {
      expect(script, contains('complete -c my-tool -e'));
    });
  });

  group('Given the PowerShell completion script', () {
    final script = CompletionShell.powershell.script('my-tool');

    test('then it registers a native argument completer', () {
      expect(
        script,
        contains("Register-ArgumentCompleter -Native -CommandName 'my-tool'"),
      );
    });

    test('then it uses the Cobra request command', () {
      expect(script, contains('__complete'));
    });
  });

  group('Given the Carapace completion spec', () {
    test('then it bridges to the Cobra protocol with parsing disabled', () {
      final spec = CompletionShell.carapace.script(
        'my-tool',
        description: 'My tool.\nMore.',
      );
      expect(spec, contains('name: "my-tool"'));
      expect(spec, contains('description: "My tool."'));
      expect(spec, contains('parsing: disabled'));
      expect(spec, contains(r'"$carapace.bridge.Cobra([my-tool])"'));
    });

    test('when the description contains quotes '
        'then they are escaped', () {
      final spec = CompletionShell.carapace.script(
        'my-tool',
        description: 'Say "hi" \\ bye',
      );
      expect(spec, contains(r'description: "Say \"hi\" \\ bye"'));
    });

    test('when there is no description then none is written', () {
      final spec = CompletionShell.carapace.script('my-tool');
      expect(spec, isNot(contains('description:')));
    });
  });
}
