import 'dart:io' show Directory, File, stderr, stdout;

import 'package:config/command.dart';
import 'package:config/config.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fixtures/completion_cli.dart';

/// The script of the leaf runner, requested via the `--completion` option.
String _leafScript(final CompletionShell shell) =>
    shell.script('leaftool', viaOption: true);

void main() {
  late StringBuffer out;
  late StringBuffer err;
  late List<String> trace;
  late CommandRunner<OptionDefinition, int> runner;

  UsageOutputHandler usage() => UsageOutputHandler(
    sinks: OutputSinks(out: out, err: err),
  );

  setUp(() {
    out = StringBuffer();
    err = StringBuffer();
    trace = [];
    runner = buildCompletionCli(
      usageOutput: usage(),
      trace: trace,
      completionOutput: out,
      completionError: err,
    );
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
      test(
        'when running `completion --shell ${shell.name}` '
        'then the ${shell.displayName} script for the executable '
        'is written to the output sink and the runner middleware runs',
        () async {
          final result = await runner.run([
            'completion',
            '--shell',
            shell.name,
          ]);
          expect(result, isNull);
          expect(
            out.toString(),
            shell.script(
              'comptool',
              description: runner.usageDefinition.description,
            ),
          );
          expect(err.toString(), isEmpty);
          expect(trace, ['middleware:comptool']);
        },
      );
    }

    test(
      'when running `completion` without a shell '
      'then the script of the shell detected in this environment is printed',
      () async {
        await runner.run(['completion']);
        expect(
          out.toString(),
          detectCompletionShell()?.script(
            'comptool',
            description: runner.usageDefinition.description,
          ),
        );
      },
      skip: detectCompletionShell() == null
          ? 'No shell is detected in this environment'
          : null,
    );
    test('when running `completion` with an unknown shell '
        'then a usage error listing the shells is reported', () async {
      await expectLater(
        runner.run(['completion', '--shell', 'tcsh']),
        throwsA(isA<UsageException>()),
      );
      expect(err.toString(), contains('bash'));
      expect(err.toString(), contains('carapace'));
    });

    test('when running `completion bash` with the shell as an argument '
        'then it is reported as an unknown subcommand', () async {
      await expectLater(
        runner.run(['completion', 'bash']),
        throwsA(
          isA<UsageException>().having(
            (final e) => e.message,
            'message',
            contains('Unknown subcommand: "bash"'),
          ),
        ),
      );
      expect(out.toString(), isEmpty);
    });

    test('when running `completion --help` '
        'then the installation instructions name the executable '
        'and are part of the description, before the usage line', () async {
      await runner.run(['completion', '--help']);
      final output = out.toString();
      for (final shell in CompletionShell.values) {
        expect(output, contains(shell.installInstruction('comptool')));
      }
      expect(output, contains('Usage: comptool completion'));
      expect(
        output.indexOf('Manual installation:'),
        inInclusiveRange(0, output.indexOf('Usage: comptool completion')),
      );
    });

    test('when running `completion --help` '
        'then the install subcommand is described and listed', () async {
      await runner.run(['completion', '--help']);
      final output = out.toString();
      expect(output, contains('run "comptool completion install"'));
      expect(
        output,
        matches(RegExp(r'install +Install the shell completion script')),
      );
    });

    test('when running `completion --help` '
        'then the usage has the persistent options, with and without '
        'a subcommand', () async {
      await runner.run(['completion', '--help']);
      expect(
        out.toString(),
        contains(
          'Usage: comptool completion [--shell=<shell>] '
          '[--command=<command>] <subcommand> [arguments]\n'
          '   or: comptool completion [--shell=<shell>] '
          '[--command=<command>]\n',
        ),
      );
    });

    test('when running `completion install --help` '
        'then the usage of the install subcommand is printed', () async {
      await runner.run(['completion', 'install', '--help']);
      expect(
        out.toString(),
        contains('Usage: comptool completion install [--dry-run]'),
      );
    });

    test('when running `help completion` '
        'then its usage is printed', () async {
      await runner.run(['help', 'completion']);
      expect(
        out.toString(),
        contains('Usage: comptool completion [--shell=<shell>]'),
      );
      expect(err.toString(), isEmpty);
    });

    test('when running `completion --shell zsh` '
        'then the script header has the installation instructions '
        'for the completion command', () async {
      await runner.run(['completion', '--shell', 'zsh']);
      final output = out.toString();
      expect(
        output,
        contains('# Generated by `comptool completion --shell zsh`.'),
      );
      for (final line
          in CompletionShell.zsh.installInstructions('comptool').split('\n')) {
        expect(output, contains('# $line'));
      }
      expect(output, isNot(contains('--completion')));
    });

    test('when running `completion --shell bash --command mywrap` '
        'then the script completes the wrapper name '
        'and sends the requests to the executable directly', () async {
      await runner.run([
        'completion',
        '--shell',
        'bash',
        '--command',
        'mywrap',
      ]);
      final output = out.toString();
      expect(output, contains('complete -F __mywrap_complete mywrap'));
      expect(output, contains("local cmd='comptool' out"));
      expect(
        output,
        contains(
          '# Generated by '
          '`comptool completion --shell bash --command mywrap`.',
        ),
      );
      expect(
        output,
        contains(
          '#   source <(comptool completion --shell bash --command mywrap)',
        ),
      );
      expect(output, contains('/etc/bash_completion.d/mywrap'));
      expect(output, contains('requested from comptool directly'));
      expect(output, isNot(contains('comptool_complete')));
    });

    for (final shell in CompletionShell.values) {
      test('when running `completion --shell ${shell.name} --command mywrap` '
          'then the ${shell.displayName} script is for the wrapper', () async {
        await runner.run([
          'completion',
          '--shell',
          shell.name,
          '--command',
          'mywrap',
        ]);
        expect(
          out.toString(),
          CompletionShell.values
              .byName(shell.name)
              .script(
                'comptool',
                description: runner.usageDefinition.description,
                commandName: 'mywrap',
              ),
        );
      });
    }

    test('when running `completion --shell zsh` '
        'then the script completes the executable as typed', () async {
      await runner.run(['completion', '--shell', 'zsh']);
      expect(out.toString(), contains(r'cmd=${(Q)words[1]}'));
      expect(out.toString(), isNot(contains("cmd='comptool'")));
    });

    test('when running `--completion zsh` '
        'then it is an unknown option since the runner has subcommands '
        'and the completion command instead', () async {
      await expectLater(
        runner.run(['--completion', 'zsh']),
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

    test('when reading the built-in global options '
        'then the completion option is not included', () {
      expect(runner.builtinPersistentOptions, [BuiltinGlobalOption.help]);
    });

    test('when printing the usage '
        'then the completion option is not listed', () {
      expect(runner.usage, isNot(contains('--completion')));
    });

    test('when running a regular command '
        'then it runs as usual', () async {
      final result = await runner.run(['build']);
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

    test('when running `completion --shell bash` '
        'then it is an unknown subcommand', () async {
      await expectLater(
        runner.run(['completion', '--shell', 'bash']),
        throwsA(isA<UsageException>()),
      );
      expect(out.toString(), isEmpty);
    });

    test('when running `--completion bash` '
        'then it is an unknown option', () async {
      await expectLater(
        runner.run(['--completion', 'bash']),
        throwsA(isA<UsageException>()),
      );
      expect(out.toString(), isEmpty);
    });

    test('when running `__complete` '
        'then it is an unknown subcommand', () async {
      await expectLater(
        runner.run(['__complete', '']),
        throwsA(isA<UsageException>()),
      );
      expect(out.toString(), isEmpty);
    });
  });

  group('Given a runner with a hidden completion command', () {
    setUp(() {
      runner = buildCompletionCli(
        usageOutput: usage(),
        completion: const CompletionSettings(hideCommand: true),
        completionOutput: out,
        completionError: err,
      );
    });

    test('when printing the usage '
        'then the completion command is not listed', () {
      expect(runner.usage, isNot(contains('Generate a shell completion')));
      expect(runner.usage, contains('build'));
    });

    test('when running `completion --shell fish` '
        'then the script is still printed', () async {
      await runner.run(['completion', '--shell', 'fish']);
      expect(out.toString(), CompletionShell.fish.script('comptool'));
    });

    test('when completing the first word '
        'then the completion command is not offered', () async {
      await runner.run(['__complete', '']);
      expect(out.toString(), isNot(contains('completion')));
    });
  });

  // The shell detection depends on the processes and the environment the
  // tests are run in, so here the shell is given. The commands with a
  // detected shell, or with none, are tested in the shell integration tests,
  // which control the environment of the fixture executable.
  group('Given a completion command that installs into a home directory', () {
    late Directory home;

    String homePath(
      final String part1, [
      final String? part2,
      final String? part3,
      final String? part4,
      final String? part5,
    ]) => p.join(home.path, part1, part2, part3, part4, part5);

    setUp(() {
      home = Directory.systemTemp.createTempSync('completion_command_test_');
      runner = buildCompletionCli(
        usageOutput: usage(),
        trace: trace,
        completionOutput: out,
        completionError: err,
        extraCommands: [
          CompletionCommand<int>(
            installer: CompletionInstaller(environment: {'HOME': home.path}),
          ),
        ],
      );
    });

    tearDown(() => home.deleteSync(recursive: true));

    group('when running `completion install --shell fish`', () {
      late String scriptPath;
      late int? result;

      setUp(() async {
        scriptPath = homePath(
          '.config',
          'fish',
          'completions',
          'comptool.fish',
        );
        result = await runner.run(['completion', 'install', '--shell', 'fish']);
      });

      test('then the script of the given shell is saved '
          'where the shell loads it from', () {
        expect(
          File(scriptPath).readAsStringSync(),
          CompletionShell.fish.script(
            'comptool',
            description: runner.usageDefinition.description,
          ),
        );
      });

      test('then the steps are printed, followed by how to activate '
          'the completion', () {
        expect(
          out.toString(),
          'Installing the Fish completion for comptool:\n'
          '  Create directory ${p.dirname(scriptPath)}\n'
          '  Write $scriptPath\n'
          'Fish loads it automatically, no reload needed.\n',
        );
      });

      test('then nothing is printed to the error sink', () {
        expect(err.toString(), isEmpty);
      });

      test('then the runner returns null after running its middleware', () {
        expect(result, isNull);
        expect(trace, ['middleware:comptool']);
      });
    });

    group('when running `completion install --shell fish --dry-run`', () {
      setUp(() async {
        await runner.run([
          'completion',
          'install',
          '--shell',
          'fish',
          '--dry-run',
        ]);
      });

      test('then the steps are printed as a dry run, '
          'without how to activate the completion', () {
        final scriptPath = homePath(
          '.config',
          'fish',
          'completions',
          'comptool.fish',
        );
        expect(
          out.toString(),
          'Installing the Fish completion for comptool '
          '(dry run, nothing is changed):\n'
          '  Create directory ${p.dirname(scriptPath)}\n'
          '  Write $scriptPath\n',
        );
      });

      test('then nothing is created in the home directory', () {
        expect(home.listSync(), isEmpty);
      });
    });

    group('when running `completion --shell zsh install`', () {
      setUp(() async {
        await runner.run(['completion', '--shell', 'zsh', 'install']);
      });

      test('then the script of the given shell is saved', () {
        expect(
          File(
            homePath('.local', 'share', 'zsh', 'site-functions', '_comptool'),
          ).readAsStringSync(),
          startsWith('#compdef comptool'),
        );
      });

      test('then the startup file of the shell loads the script', () {
        expect(
          File(homePath('.zshrc')).readAsStringSync(),
          contains(p.join('site-functions', '_comptool')),
        );
      });

      test('then the added startup file lines are printed', () {
        expect(
          out.toString(),
          contains(
            '  Create ${homePath('.zshrc')}:\n'
            '    # comptool shell completion, '
            'added by `comptool completion install`.\n',
          ),
        );
      });
    });

    test('when running `completion install --shell zsh --dry-run` '
        'with the persistent option after the subcommand '
        'then the steps for the given shell are printed '
        'and nothing is created', () async {
      await runner.run([
        'completion',
        'install',
        '--shell',
        'zsh',
        '--dry-run',
      ]);
      expect(
        out.toString(),
        startsWith(
          'Installing the Zsh completion for comptool '
          '(dry run, nothing is changed):\n',
        ),
      );
      expect(home.listSync(), isEmpty);
    });

    test('when running `completion --shell fish install --command mywrap` '
        'then the script for the wrapper is saved under its name', () async {
      await runner.run([
        'completion',
        '--shell',
        'fish',
        'install',
        '--command',
        'mywrap',
      ]);
      expect(
        File(
          homePath('.config', 'fish', 'completions', 'mywrap.fish'),
        ).readAsStringSync(),
        CompletionShell.fish.script(
          'comptool',
          description: runner.usageDefinition.description,
          commandName: 'mywrap',
        ),
      );
      expect(
        out.toString(),
        startsWith('Installing the Fish completion for mywrap:\n'),
      );
    });

    group('when running `completion install --shell bash` '
        'with the path of a wrapper as the command name', () {
      const wrapperContent = '#!/bin/sh\nexec comptool "\$@"\n';
      late File wrapper;
      late Object? error;

      setUp(() async {
        wrapper = File(homePath('bin', 'mywrap'));
        wrapper.parent.createSync();
        wrapper.writeAsStringSync(wrapperContent);
        error = null;
        try {
          await runner.run([
            'completion',
            'install',
            '--shell',
            'bash',
            '--command',
            wrapper.path,
          ]);
        } on UsageException catch (e) {
          error = e;
        }
      });

      test('then a usage error tells to specify the name of the command', () {
        expect(
          error,
          isA<CommandUsageException>().having(
            (final e) => e.message,
            'message',
            'install: Cannot install the completion for "${wrapper.path}". '
                'Specify the name of the command with --command, '
                'not its path.',
          ),
        );
      });

      test('then the error and the install command usage are printed once', () {
        final exception = error as CommandUsageException;
        expect(
          err.toString(),
          '${exception.message}\n\n${exception.command.usage}',
        );
      });

      test('then the wrapper is not overwritten', () {
        expect(wrapper.readAsStringSync(), wrapperContent);
      });

      test('then nothing is created', () {
        expect(home.listSync(recursive: true).map((final e) => e.path), [
          wrapper.parent.path,
          wrapper.path,
        ]);
      });

      test('then no installation is printed', () {
        expect(out.toString(), isEmpty);
      });
    });

    group(
      'when the runner does not throw usage exceptions '
      'and `completion install` is given a path as the command name',
      () {
        const commandName = '../mywrap';
        const message =
            'install: Cannot install the completion for "$commandName". '
            'Specify the name of the command with --command, not its path.';
        late int? result;

        setUp(() async {
          runner = buildCompletionCli(
            usageOutput: UsageOutputHandler(
              sinks: OutputSinks(out: out, err: err),
              exceptionSettings: const UsageExceptionSettings(
                noUsageException: true,
              ),
            ),
            trace: trace,
            completionOutput: out,
            completionError: err,
            extraCommands: [
              CompletionCommand<int>(
                installer: CompletionInstaller(
                  environment: {'HOME': home.path},
                ),
              ),
            ],
          );
          result = await runner.run([
            'completion',
            'install',
            '--shell',
            'bash',
            '--command',
            commandName,
          ]);
        });

        test('then the runner returns null', () {
          expect(result, isNull);
        });

        test(
          'then the error and the install command usage are printed once',
          () {
            const usageHeading = 'Usage: comptool completion install';
            expect(message.allMatches(err.toString()), hasLength(1));
            expect(usageHeading.allMatches(err.toString()), hasLength(1));
          },
        );

        test('then nothing is printed about an installation', () {
          expect(out.toString(), isEmpty);
        });

        test('then nothing is created', () {
          expect(home.listSync(), isEmpty);
        });
      },
    );

    test('when running `completion install --shell zsh --dry-run` '
        'with a parent directory in the command name '
        'then a usage error is reported', () async {
      await expectLater(
        runner.run([
          'completion',
          'install',
          '--shell',
          'zsh',
          '--dry-run',
          '--command',
          '../mywrap',
        ]),
        throwsA(isA<UsageException>()),
      );
    });

    test('when running `completion install --shell fish` twice '
        'then the second run only writes the script again', () async {
      await runner.run(['completion', 'install', '--shell', 'fish']);
      out.clear();
      await runner.run(['completion', 'install', '--shell', 'fish']);
      expect(
        out.toString(),
        'Installing the Fish completion for comptool:\n'
        '  Write '
        '${homePath('.config', 'fish', 'completions', 'comptool.fish')}\n'
        'Fish loads it automatically, no reload needed.\n',
      );
    });

    test('when running `completion install` with an unexpected argument '
        'then a usage error is reported and nothing is created', () async {
      await expectLater(
        runner.run(['completion', 'install', 'fish']),
        throwsA(isA<UsageException>()),
      );
      expect(home.listSync(), isEmpty);
    });
  });

  group('Given a runner defining its own completion subcommand', () {
    setUp(() {
      runner = buildCompletionCli(
        usageOutput: usage(),
        trace: trace,
        extraCommands: [
          CommandImpl.leafWithRunFunction(
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
      final result = await runner.run(['completion']);
      expect(result, 7);
      expect(trace, contains('own completion'));
    });

    test('when listing the subcommands '
        'then the completion command appears once', () {
      final names = runner.subcommands.map((final c) => c.name);
      expect(names.where((final n) => n == 'completion'), hasLength(1));
    });

    test('when running `--completion bash` '
        'then it is an unknown option as well', () async {
      await expectLater(
        runner.run(['--completion', 'bash']),
        throwsA(isA<UsageException>()),
      );
      expect(out.toString(), isEmpty);
    });
  });

  group('Given a runner without subcommands', () {
    setUp(() {
      runner = buildLeafCompletionCli(
        usageOutput: usage(),
        completionOutput: out,
        completionError: err,
      );
    });

    test('when listing the subcommands then there are none', () {
      expect(runner.subcommands, isEmpty);
    });

    test('when reading the built-in global options '
        'then the completion option is included', () {
      expect(runner.builtinPersistentOptions, [
        BuiltinGlobalOption.help,
        BuiltinGlobalOption.completion,
      ]);
    });

    test('when running `--completion bash` '
        'then the script header has the installation instructions '
        'for the completion option', () async {
      await runner.run(['--completion', 'bash']);
      final output = out.toString();
      expect(output, contains('# Generated by `leaftool --completion bash`.'));
      expect(output, contains('#   source <(leaftool --completion bash)'));
      expect(output, isNot(contains('leaftool completion')));
    });

    test('when printing the usage '
        'then the completion option is listed among the global options '
        'with the shells as its values', () {
      expect(runner.usage, contains('Global options:'));
      expect(
        runner.usage,
        matches(RegExp(r'--completion +Print the shell completion script')),
      );
      expect(
        runner.usage,
        contains('values: [bash, zsh, fish, powershell, carapace]'),
      );
    });

    test('when running `--completion bash` '
        'then the Bash script for the executable is printed', () async {
      final result = await runner.run(['--completion', 'bash']);
      expect(result, isNull);
      expect(out.toString(), _leafScript(CompletionShell.bash));
    });

    test('when running `--completion=powershell` '
        'then the PowerShell script is printed', () async {
      await runner.run(['--completion=powershell']);
      expect(out.toString(), _leafScript(CompletionShell.powershell));
    });

    test('when running `--completion` without a shell '
        'then the missing value is reported '
        'along with the other usage errors', () async {
      await expectLater(
        runner.run(['--completion']),
        throwsA(
          isA<UsageException>().having(
            (final e) => e.message,
            'message',
            allOf(
              contains('Missing value for option: --completion'),
              contains('"--target" is mandatory'),
            ),
          ),
        ),
      );
      expect(err.toString(), contains('Missing value for option'));
    });

    test('when running `--completion=` with an empty shell '
        'then the invalid value is reported listing the shells', () async {
      await expectLater(
        runner.run(['--completion=']),
        throwsA(
          isA<UsageException>().having(
            (final e) => e.message,
            'message',
            allOf(
              contains('Invalid value for option "--completion": ""'),
              contains('bash|zsh|fish|powershell|carapace'),
            ),
          ),
        ),
      );
    });

    test('when `--help` is given with an invalid `--completion` shell '
        'then the invalid shell is reported', () async {
      await expectLater(
        runner.run(['--help', '--completion', 'ksh']),
        throwsA(
          isA<UsageException>().having(
            (final e) => e.message,
            'message',
            contains('Invalid value for option "--completion": "ksh"'),
          ),
        ),
      );
    });

    for (final args in [
      ['--help', '--completion', 'bash'],
      ['--completion', 'bash', '--help'],
    ]) {
      test('when running `${args.join(' ')}` '
          'then the usage is printed instead of the script', () async {
        await runner.run(args);
        expect(out.toString(), runner.usage);
      });
    }

    test('when running `--completion` with an unknown shell '
        'then the invalid value is reported', () async {
      await expectLater(
        runner.run(['--completion', 'ksh']),
        throwsA(
          isA<UsageException>().having(
            (final e) => e.message,
            'message',
            contains(
              'Invalid value for option "--completion": "ksh" '
              'is not in bash|zsh|fish|powershell|carapace',
            ),
          ),
        ),
      );
    });

    test(
      'when running `--completion` with a shell in the wrong case '
      'then the invalid value is reported since names are case sensitive',
      () async {
        await expectLater(
          runner.run(['--completion', 'Bash']),
          throwsA(
            isA<UsageException>().having(
              (final e) => e.message,
              'message',
              contains('Invalid value for option "--completion": "Bash"'),
            ),
          ),
        );
      },
    );

    test('when `--completion <shell>` is given with other arguments '
        'then the script is printed and the mandatory option is not '
        'required, like with the help option', () async {
      await runner.run(['--mode', 'debug', '--completion', 'bash']);
      expect(out.toString(), _leafScript(CompletionShell.bash));
      expect(err.toString(), isEmpty);
    });

    test(
      'when `--completion <shell>` is given with an unknown option '
      'then the unknown option is reported',
      () async {
        await expectLater(
          runner.run(['--completion', 'bash', '--bogus']),
          throwsA(
            isA<UsageException>().having(
              (final e) => e.message,
              'message',
              contains('Unknown option: --bogus'),
            ),
          ),
        );
        expect(out.toString(), isEmpty);
        expect(err.toString(), contains('Unknown option: --bogus'));
      },
    );

    test('when running `__complete` then the request is served', () async {
      await runner.run(['__complete', '--mode', '']);
      expect(
        out.toString(),
        'debug\tDebug build\nprofile\n'
        'release\tOptimized build\n:4\n',
      );
    });
  });

  group('Given the completion settings', () {
    test('when created with defaults then completion is enabled, '
        'the command is visible and the runner returns after '
        'completion output', () {
      const settings = CompletionSettings();
      expect(settings.enabled, isTrue);
      expect(settings.hideCommand, isFalse);
      expect(settings.exitAfterResponse, isFalse);
      expect(settings.sinks.out, same(stdout));
      expect(settings.sinks.err, same(stderr));
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
        expect(command, contains('my-tool completion --shell ${shell.name}'));
        expect(shell.installInstructions('my-tool'), contains(command));
        final short = shell.installInstruction('my-tool');
        expect(short, startsWith(command));
        final location = shell.installLocation;
        if (location != null) expect(short, endsWith('# in $location'));
      });

      test('when generating the ${shell.displayName} install instructions '
          'then they end with how to activate the completion', () {
        expect(
          shell.installInstructions('my-tool'),
          endsWith(shell.activationInstruction),
        );
      });

      test('when generating the ${shell.displayName} script for a wrapper '
          'then it is installed under the wrapper name '
          'and generated with the command option', () {
        final script = shell.script('my-tool', commandName: 'wrap');
        expect(
          script,
          contains(
            'Generated by `my-tool completion --shell ${shell.name} '
            '--command wrap`.',
          ),
        );
        expect(
          shell.installCommand('my-tool', commandName: 'wrap'),
          allOf(
            contains(
              'my-tool completion --shell ${shell.name} --command wrap',
            ),
            isNot(contains('my-tool.')),
          ),
        );
        expect(
          shell.installInstructions('my-tool', commandName: 'wrap'),
          isNot(contains('_my-tool')),
        );
      });
    }

    test('when generating a script for a wrapper name with a quote '
        'then the executable is quoted for the shell', () {
      expect(shellQuote("it's"), r"'it'\''s'");
      expect(
        CompletionShell.bash.script("it's", commandName: 'wrap'),
        contains(r"local cmd='it'\''s' out"),
      );
      expect(
        CompletionShell.powershell.script("it's", commandName: 'wrap'),
        contains(r"$program = 'it''s'"),
      );
    });

    test('when making a shell word of a plain name or path '
        'then it is unchanged', () {
      expect(shellWord('my-tool'), 'my-tool');
      expect(shellWord('~/bin/my_tool.sh'), '~/bin/my_tool.sh');
    });

    test('when making a shell word of a name the shell would split or expand '
        'then it is quoted', () {
      expect(shellWord('/opt/My Tools/tool'), "'/opt/My Tools/tool'");
      expect(shellWord(r'$tool'), r"'$tool'");
      expect(shellWord(''), "''");
    });

    test('when generating the script command for an executable path '
        'with a space then the path is quoted', () {
      expect(
        CompletionShell.bash.scriptCommand('/opt/My Tools/tool'),
        "'/opt/My Tools/tool' completion --shell bash",
      );
      expect(
        CompletionShell.fish.scriptCommand(
          '/opt/My Tools/tool',
          viaOption: true,
        ),
        "'/opt/My Tools/tool' --completion fish",
      );
    });

    test('when generating the PowerShell script command for an executable '
        'path with a space then the quoted path is run with the call '
        'operator', () {
      expect(
        CompletionShell.powershell.scriptCommand("/opt/My Tool's/tool"),
        "& '/opt/My Tool''s/tool' completion --shell powershell",
      );
    });

    test('when generating the script command for a wrapper name '
        'with a space then the name is quoted', () {
      expect(
        CompletionShell.zsh.scriptCommand('my-tool', commandName: 'my wrap'),
        "my-tool completion --shell zsh --command 'my wrap'",
      );
      expect(
        CompletionShell.powershell.scriptCommand(
          'my-tool',
          commandName: 'my wrap',
        ),
        "my-tool completion --shell powershell --command 'my wrap'",
      );
    });

    test('when generating the Bash script for a wrapper path with a space '
        'then the completion is registered for the path as one word', () {
      expect(
        CompletionShell.bash.script('my-tool', commandName: '/tmp/my wrapper'),
        endsWith("complete -F ___tmp_my_wrapper_complete '/tmp/my wrapper'\n"),
      );
    });

    test('when generating the Bash and Zsh install instructions '
        'then the shell is reloaded with exec', () {
      expect(CompletionShell.bash.activationInstruction, contains('exec bash'));
      expect(CompletionShell.zsh.activationInstruction, contains('exec zsh'));
    });

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
