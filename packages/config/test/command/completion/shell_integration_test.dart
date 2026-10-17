/// Integration tests running the fixture CLI compiled to an executable:
/// the completion protocol as a process, and the generated completion
/// scripts in the real shells.
///
/// Each shell's tests run only if the shell is installed. To make them
/// mandatory (as in CI), list the shells in the environment variable
/// `CLI_COMPLETION_SHELLS`, e.g. `CLI_COMPLETION_SHELLS=bash,zsh,fish`;
/// the tests for a listed shell that is not installed then fail.
/// The shell executables are looked up on the PATH, or can be given
/// explicitly as `CLI_COMPLETION_BASH`, `CLI_COMPLETION_ZSH`,
/// `CLI_COMPLETION_FISH`, `CLI_COMPLETION_PWSH` and `CLI_COMPLETION_CARAPACE`.
///
/// On Windows, only the process-level tests and the PowerShell tests run;
/// the other shells' harnesses are POSIX scripts.
@Timeout(Duration(minutes: 5))
library;

import 'dart:convert' show jsonDecode, utf8;
import 'dart:io';

import 'package:config/command.dart' show CompletionShell;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fixtures/completion_cli.dart'
    show afterRunnerMarker, buildCompletionCli;

const _exeName = 'comptool';

/// The shells (and completion frameworks) under test, by executable name.
const _shells = ['bash', 'zsh', 'fish', 'pwsh', 'carapace'];

/// The shells whose harnesses run on this platform.
final _platformShells = Platform.isWindows ? const ['pwsh'] : _shells;

void main() {
  final required = (Platform.environment['CLI_COMPLETION_SHELLS'] ?? '')
      .split(',')
      .map((final s) => s.trim())
      .where((final s) => s.isNotEmpty)
      .toSet();
  final installed = {
    for (final shell in _platformShells) shell: _findShell(shell),
  };
  for (final shell in required) {
    if (installed[shell] == null) {
      test('Given $shell is required by CLI_COMPLETION_SHELLS '
          'then it is installed and tested on this platform', () {
        fail(
          _platformShells.contains(shell)
              ? '$shell is not installed or not on the PATH'
              : '$shell is not tested on ${Platform.operatingSystem}',
        );
      });
    }
  }

  final env = _Environment();

  setUpAll(() async {
    await env.setUp();
  });

  tearDownAll(() {
    env.tearDown();
  });

  _executableTests(env);

  String? skipUnless(final String shell) {
    if (!_platformShells.contains(shell)) {
      return '$shell is not tested on ${Platform.operatingSystem}';
    }
    return installed[shell] == null ? '$shell is not installed' : null;
  }

  // On macOS, /bin/bash is version 3.2 while a newer Bash is usually
  // installed elsewhere; test both when they differ.
  final bashes = <String>{
    if (installed['bash'] case final String bash) bash,
    if (Platform.isMacOS && File('/bin/bash').existsSync()) '/bin/bash',
  };
  for (final bash in bashes) {
    _bashTests(env, bash, skip: skipUnless('bash'));
  }
  _zshTests(env, installed['zsh'], skip: skipUnless('zsh'));
  _fishTests(env, installed['fish'], skip: skipUnless('fish'));
  _powershellTests(env, installed['pwsh'], skip: skipUnless('pwsh'));
  _carapaceTests(env, installed['carapace'], skip: skipUnless('carapace'));
}

/// The completion protocol at the process level: the executable prints after
/// `runner()` returns (see the fixture's `main`), which must not reach the
/// completion output.
void _executableTests(final _Environment env) {
  group('Given the fixture CLI compiled to an executable '
      'that prints after the runner returns', () {
    final description = buildCompletionCli().usageDefinition.description;

    test('when running a regular command '
        'then the output after the runner is printed', () async {
      final result = await env.run(env.exePath, ['build']);
      expect(result.stdout, contains(afterRunnerMarker));
    });

    test(
      'when serving a completion request '
      'then the process exits with code 0 right after the response',
      () async {
        final result = await env.run(env.exePath, ['__complete', 'bu']);
        expect(result.stdout, 'build\tBuild the project.\n:4\n');
        expect(result.exitCode, 0);
      },
    );

    test('when a completion request fails '
        'then the process exits with code 0 right after the error response '
        'and the failure is reported on stderr', () async {
      final result = await env.run(env.exePath, [
        '__complete',
        'build',
        '--project',
        'boom',
        '--env',
        '',
      ]);
      expect(result.stdout, ':1\n');
      expect(result.exitCode, 0);
      expect(result.stderr, contains('Completion failed'));
    });

    test('when printing a completion script with the completion command '
        'then the process exits right after the script', () async {
      final result = await env.run(env.exePath, ['completion', 'bash']);
      expect(
        result.stdout,
        CompletionShell.bash.script(_exeName, description: description),
      );
      expect(result.exitCode, 0);
    });

    test('when printing a completion script with the completion option '
        'then the process exits right after the script', () async {
      final result = await env.run(env.exePath, ['--completion=zsh']);
      expect(
        result.stdout,
        CompletionShell.zsh.script(_exeName, description: description),
      );
      expect(result.exitCode, 0);
    });

    test('when the completion script request is invalid '
        'then the usage error is reported and the process does not exit '
        'early', () async {
      final result = await env.run(
        env.exePath,
        ['--completion', 'tcsh'],
        expectSuccess: false,
      );
      expect(result.exitCode, 64);
      expect(result.stderr, contains('Unknown shell "tcsh"'));
      expect(result.stdout, isNot(contains(afterRunnerMarker)));
    });
  });
}

void _bashTests(
  final _Environment env,
  final String bash, {
  required final String? skip,
}) {
  group('Given the Bash completion script sourced in $bash', () {
    Future<List<String>> complete(final List<String> words) async {
      final result = await env.run(bash, [
        env.harnessPath('bash_harness.sh'),
        env.scriptPath('bash'),
        ...words,
      ]);
      return result.lines;
    }

    test('when sourced then a completion function is registered '
        'for the executable', () async {
      final result = await env.run(bash, [
        '-c',
        'source "\$1" && complete -p $_exeName',
        'bash',
        env.scriptPath('bash'),
      ]);
      expect(
        result.stdout.trim(),
        'complete -F __${_exeName}_complete $_exeName',
      );
    });

    test('when completing the first word '
        'then the non-hidden subcommands are offered', () async {
      expect(await complete(['']), [
        'build',
        'deploy',
        'export',
        'version',
        'db',
        'completion',
      ]);
    });

    test('when completing a subcommand prefix '
        'then only the matching subcommand is offered', () async {
      expect(await complete(['bu']), ['build']);
    });

    test('when completing a dash then the options are offered', () async {
      expect(
        await complete(['-']),
        containsAll(['--config', '-c', '--verbose', '--no-verbose', '-h']),
      );
    });

    test('when completing an enum option value '
        'then its values are offered', () async {
      expect(await complete(['build', '--mode', '']), [
        'debug',
        'profile',
        'release',
      ]);
    });

    test('when completing an option value attached with an equals sign '
        'then the value part is completed', () async {
      // Bash splits the word at '=' by default.
      expect(await complete(['build', '--mode', '=', 're']), ['release']);
    });

    test('when completing a later list element of a multi-option '
        'then the earlier elements are kept', () async {
      expect(await complete(['build', '--tags', 'fast,s']), [r'fast\,slow']);
    });

    test('when completing a directory option '
        'then only directories are offered', () async {
      expect(await complete(['build', '--out', '']), ['sub']);
    });

    test('when completing a file option '
        'then files are offered', () async {
      expect(await complete(['--config', 'f']), ['f.txt']);
    });

    test('when completing a file option with extensions '
        'then only matching files and directories are offered', () async {
      expect(
        await complete(['build', '--spec', '']),
        unorderedEquals(['sub', 'a.yaml', 'b.yml']),
      );
    });

    test('when completing a positional argument '
        'then its allowed values are offered', () async {
      expect(await complete(['deploy', '']), ['staging', 'production']);
    });

    test('when nothing can be completed then nothing is offered', () async {
      expect(await complete(['build', '']), isEmpty);
    });
  }, skip: skip);
}

void _zshTests(
  final _Environment env,
  final String? zsh, {
  required final String? skip,
}) {
  group('Given the Zsh completion script in an interactive Zsh', () {
    /// Types [line] followed by TAB in an interactive zsh, returning the
    /// resulting command line buffer and the raw terminal output.
    Future<({String buffer, String output})> completeLine(
      final String line, {
      final bool installInFpath = false,
    }) async {
      final result = await env.run(
        zsh!,
        ['-f', env.harnessPath('zsh_harness.zsh'), line],
        environment: {
          'ZSH_INIT': env.harnessPath('zsh_init.zsh'),
          'ZSH_COMPDUMP': p.join(env.root.path, 'zcompdump'),
          'ZSH_BUFFER_FILE': p.join(env.root.path, 'zsh_buffer.txt'),
          'COMPLETION_SCRIPT': env.scriptPath('zsh'),
          'COMPLETION_INSTALL': installInFpath ? 'fpath' : 'source',
          'COMPLETION_FPATH': env.fpathDir.path,
        },
      );
      final buffer = result.lines.firstWhere(
        (final l) => l.startsWith('BUFFER:'),
        orElse: () => fail('no buffer in harness output:\n${result.stdout}'),
      );
      return (
        buffer: buffer.substring('BUFFER:'.length),
        output: result.stdout,
      );
    }

    test('when sourced after compinit '
        'then the completion function is registered', () async {
      final result = await env.run(zsh!, [
        '-f',
        '-c',
        'autoload -Uz compinit && compinit -u -d "\$1" && source "\$2" && '
            'print -r -- "\${_comps[$_exeName]}"',
        'zsh',
        p.join(env.root.path, 'zcompdump_check'),
        env.scriptPath('zsh'),
      ]);
      expect(result.stdout.trim(), '_$_exeName');
    });

    test('when completing a unique subcommand prefix '
        'then the subcommand is inserted', () async {
      final result = await completeLine('$_exeName bu');
      expect(result.buffer, '$_exeName build ');
    });

    test('when installed in fpath and completing a unique subcommand prefix '
        'then the subcommand is inserted', () async {
      final result = await completeLine('$_exeName bu', installInFpath: true);
      expect(result.buffer, '$_exeName build ');
    });

    test('when completing the first word '
        'then the subcommands are listed with descriptions', () async {
      final result = await completeLine('$_exeName ');
      expect(result.output, contains('build'));
      expect(result.output, contains('Build the project.'));
      expect(result.output, contains('deploy'));
      expect(result.output, contains('completion'));
      expect(result.output, isNot(contains('internal')));
    });

    test('when completing an enum option value '
        'then the values are listed with descriptions', () async {
      final result = await completeLine('$_exeName build --mode ');
      expect(result.buffer, '$_exeName build --mode ');
      expect(result.output, contains('debug'));
      expect(result.output, contains('Debug build'));
      expect(result.output, contains('profile'));
      expect(result.output, contains('release'));
    });

    test('when completing a unique enum option value '
        'then it is inserted', () async {
      final result = await completeLine('$_exeName build --mode re');
      expect(result.buffer, '$_exeName build --mode release ');
    });

    test('when completing an option value attached with an equals sign '
        'then the value is inserted after the option', () async {
      final result = await completeLine('$_exeName build --mode=re');
      expect(result.buffer, '$_exeName build --mode=release ');
    });

    test('when completing a later list element of a multi-option '
        'then the earlier elements are kept', () async {
      final result = await completeLine('$_exeName build --tags fast,s');
      expect(result.buffer, '$_exeName build --tags fast,slow ');
    });

    test('when completing a directory option '
        'then the directory is inserted', () async {
      final result = await completeLine('$_exeName build --out su');
      expect(result.buffer, '$_exeName build --out sub/');
    });

    test('when completing a file option then the file is inserted', () async {
      final result = await completeLine('$_exeName --config f.t');
      expect(result.buffer, '$_exeName --config f.txt ');
    });

    test('when completing a file option with extensions '
        'then the matching file is inserted', () async {
      final result = await completeLine('$_exeName build --spec a.');
      expect(result.buffer, '$_exeName build --spec a.yaml ');
    });

    test('when completing a positional argument '
        'then its allowed values are listed', () async {
      final result = await completeLine('$_exeName deploy ');
      expect(result.output, contains('staging'));
      expect(result.output, contains('production'));
    });

    test('when nothing can be completed '
        'then no files are offered', () async {
      final result = await completeLine('$_exeName build ');
      expect(result.buffer, '$_exeName build ');
      expect(result.output, isNot(contains('f.txt')));
    });
  }, skip: skip);
}

void _fishTests(
  final _Environment env,
  final String? fish, {
  required final String? skip,
}) {
  group('Given the Fish completion script sourced in Fish', () {
    /// Completes [line] with fish's `complete -C`,
    /// returning the candidates as `value<TAB>description` lines.
    Future<List<String>> complete(final String line) async {
      final result = await env.run(fish!, [
        '--no-config',
        '-c',
        'source "\$argv[1]"; complete -C "\$argv[2]"',
        env.scriptPath('fish'),
        line,
      ]);
      return result.lines;
    }

    test('when completing the first word '
        'then the subcommands are offered with descriptions', () async {
      final lines = await complete('$_exeName ');
      expect(
        lines,
        containsAll([
          'build\tBuild the project.',
          'deploy\tDeploy a bundle to a target.',
          'completion\tGenerate a shell completion script.',
        ]),
      );
      expect(_values(lines), isNot(contains('internal')));
    });

    test('when completing a subcommand prefix '
        'then only the matching subcommand is offered', () async {
      expect(_values(await complete('$_exeName bu')), ['build']);
    });

    test('when completing a dash then the options are offered', () async {
      expect(
        _values(await complete('$_exeName build -')),
        containsAll(['-m', '--mode', '--no-verbose', '--config']),
      );
    });

    test('when completing an enum option value '
        'then its values are offered with descriptions', () async {
      expect(await complete('$_exeName build --mode '), [
        'debug\tDebug build',
        'profile',
        'release\tOptimized build',
      ]);
    });

    test('when completing an option value attached with an equals sign '
        'then the option prefix is kept', () async {
      expect(_values(await complete('$_exeName build --mode=re')), [
        '--mode=release',
      ]);
    });

    test('when completing a later list element of a multi-option '
        'then the earlier elements are kept', () async {
      expect(_values(await complete('$_exeName build --tags fast,s')), [
        'fast,slow',
      ]);
    });

    test('when completing a directory option '
        'then only directories are offered', () async {
      expect(_values(await complete('$_exeName build --out ')), ['sub/']);
    });

    test('when completing a file option then files are offered', () async {
      expect(_values(await complete('$_exeName --config f')), ['f.txt']);
    });

    test('when completing a file option with extensions '
        'then only matching files and directories are offered', () async {
      expect(
        _values(await complete('$_exeName build --spec ')),
        unorderedEquals(['a.yaml', 'b.yml', 'sub/']),
      );
    });

    test('when completing a positional argument '
        'then its allowed values are offered', () async {
      expect(
        _values(await complete('$_exeName deploy ')),
        unorderedEquals(['staging', 'production']),
      );
    });

    test('when nothing can be completed then nothing is offered', () async {
      expect(await complete('$_exeName build '), isEmpty);
    });
  }, skip: skip);
}

void _powershellTests(
  final _Environment env,
  final String? pwsh, {
  required final String? skip,
}) {
  group('Given the PowerShell completion script loaded in PowerShell', () {
    /// Completes [line] with `TabExpansion2`, returning the completion
    /// results as (text, listItem, type, toolTip) records.
    Future<List<({String text, String item, String type, String tip})>>
    complete(final String line) async {
      final result = await env.run(pwsh!, [
        '-NoProfile',
        '-NonInteractive',
        '-File',
        env.harnessPath('ps_harness.ps1'),
        '-Script',
        env.scriptPath('powershell'),
        '-Line',
        line,
      ]);
      return [
        for (final l in result.lines)
          if (l.split('\t') case [
            final text,
            final item,
            final type,
            final tip,
          ])
            (text: text, item: item, type: type, tip: tip),
      ];
    }

    test('when completing the first word '
        'then the subcommands are offered with tool tips', () async {
      final results = await complete('$_exeName ');
      final items = results.map((final r) => r.item);
      expect(items, containsAll(['build', 'deploy', 'db', 'completion']));
      expect(items, isNot(contains('internal')));
      final build = results.firstWhere((final r) => r.item == 'build');
      expect(build.tip, 'Build the project.');
      expect(build.type, 'ParameterValue');
    });

    test('when completing a subcommand prefix '
        'then only the matching subcommand is offered', () async {
      final results = await complete('$_exeName bu');
      expect(results.map((final r) => r.text.trim()), ['build']);
    });

    test('when completing an enum option value '
        'then its values are offered', () async {
      final results = await complete('$_exeName build --mode ');
      expect(results.map((final r) => r.item), ['debug', 'profile', 'release']);
      expect(results.last.tip, 'Optimized build');
    });

    test('when completing an option value attached with an equals sign '
        'then the option prefix is kept', () async {
      final results = await complete('$_exeName build --mode=re');
      expect(results.map((final r) => r.text.trim()), ['--mode=release']);
    });

    test('when completing a later list element of a multi-option '
        'then the earlier elements are kept', () async {
      final results = await complete('$_exeName build --tags fast,s');
      expect(results.map((final r) => r.item), ['fast,slow']);
    });

    test('when completing a directory option '
        'then only directories are offered', () async {
      final results = await complete('$_exeName build --out ');
      expect(results.map((final r) => r.item), ['sub']);
      expect(results.single.type, 'ProviderContainer');
    });

    test('when completing a file option then files are offered', () async {
      final results = await complete('$_exeName --config f');
      expect(results.map((final r) => r.item), ['f.txt']);
    });

    test('when completing a file option with extensions '
        'then only matching files and directories are offered', () async {
      final results = await complete('$_exeName build --spec ');
      expect(
        results.map((final r) => r.item),
        unorderedEquals(['sub', 'a.yaml', 'b.yml']),
      );
    });

    test('when completing a positional argument '
        'then its allowed values are offered', () async {
      final results = await complete('$_exeName deploy ');
      expect(
        results.map((final r) => r.item),
        unorderedEquals(['staging', 'production']),
      );
    });

    test('when nothing can be completed then no files are offered', () async {
      final results = await complete('$_exeName build ');
      expect(results.map((final r) => r.item.trim()), isNot(contains('f.txt')));
      expect(results.map((final r) => r.text.trim()), everyElement(isEmpty));
    });
  }, skip: skip);
}

void _carapaceTests(
  final _Environment env,
  final String? carapace, {
  required final String? skip,
}) {
  group(
    'Given the Carapace spec installed in the Carapace specs directory',
    () {
      /// Completes [words] via `carapace <spec> export`,
      /// returning the values with their descriptions.
      Future<List<({String value, String description})>> complete(
        final List<String> words,
      ) async {
        final result = await env.run(carapace!, [
          _exeName,
          'export',
          _exeName,
          ...words,
        ]);
        final json = jsonDecode(result.stdout) as Map<String, dynamic>;
        return [
          for (final value in json['values'] as List)
            (
              value: (value as Map)['value'] as String,
              description: (value['description'] as String?) ?? '',
            ),
        ];
      }

      test('when detecting the completion framework of the executable '
          'then Cobra is detected', () async {
        final result = await env.run(carapace!, ['--detect', _exeName]);
        // Carapace reports the detected framework on stderr.
        expect('${result.stdout}${result.stderr}'.trim(), 'cobra');
      });

      test('when completing the first word '
          'then the subcommands are offered with descriptions', () async {
        final results = await complete(['']);
        expect(
          results.map((final r) => r.value),
          containsAll(['build', 'deploy', 'db', 'version', 'completion']),
        );
        expect(results.map((final r) => r.value), isNot(contains('internal')));
        final build = results.firstWhere((final r) => r.value == 'build');
        expect(build.description, 'Build the project.');
      });

      test('when completing a subcommand prefix '
          'then only the matching subcommand is offered', () async {
        final results = await complete(['bu']);
        expect(results.map((final r) => r.value), ['build']);
      });

      test('when completing an enum option value '
          'then its values are offered', () async {
        final results = await complete(['build', '--mode', '']);
        expect(
          results.map((final r) => r.value),
          unorderedEquals(['debug', 'profile', 'release']),
        );
      });

      test('when completing a later list element of a multi-option '
          'then the earlier elements are kept', () async {
        final results = await complete(['build', '--tags', 'fast,s']);
        expect(results.map((final r) => r.value), ['fast,slow']);
      });

      test('when completing a directory option '
          'then only directories are offered', () async {
        final results = await complete(['build', '--out', '']);
        expect(results.map((final r) => r.value), ['sub/']);
      });

      test('when completing a file option then files are offered', () async {
        final results = await complete(['--config', 'f']);
        expect(results.map((final r) => r.value), ['f.txt']);
      });

      test('when completing a file option with extensions '
          'then only matching files and directories are offered', () async {
        final results = await complete(['build', '--spec', '']);
        expect(
          results.map((final r) => r.value),
          unorderedEquals(['a.yaml', 'b.yml', 'sub/']),
        );
      });

      test('when nothing can be completed then nothing is offered', () async {
        expect(await complete(['build', '']), isEmpty);
      });
    },
    skip: skip,
  );
}

/// The values of `value<TAB>description` lines.
List<String> _values(final List<String> lines) => [
  for (final line in lines) line.split('\t').first,
];

/// Looks up the executable of [shell] via `CLI_COMPLETION_<SHELL>`
/// or on the PATH.
String? _findShell(final String shell) {
  final explicit =
      Platform.environment['CLI_COMPLETION_${shell.toUpperCase()}'];
  if (explicit != null && explicit.isNotEmpty) {
    return File(explicit).existsSync() ? explicit : null;
  }
  final path = Platform.environment['PATH'] ?? '';
  final extensions = Platform.isWindows ? ['.exe', ''] : [''];
  for (final dir in path.split(Platform.isWindows ? ';' : ':')) {
    if (dir.isEmpty) continue;
    for (final ext in extensions) {
      final candidate = p.join(dir, '$shell$ext');
      if (File(candidate).existsSync()) return candidate;
    }
  }
  return null;
}

class _ProcessOutput {
  final String stdout;
  final String stderr;
  final int exitCode;

  _ProcessOutput(this.stdout, this.stderr, this.exitCode);

  /// The non-empty lines of [stdout], without line terminators.
  List<String> get lines => [
    for (final line in stdout.split('\n'))
      if (line.trim().isNotEmpty)
        line.endsWith('\r') ? line.substring(0, line.length - 1) : line,
  ];
}

/// The compiled fixture executable, the generated completion scripts, the
/// shell harness scripts, and a working directory with files to complete.
class _Environment {
  late final Directory root;
  late final Directory binDir;
  late final Directory scriptDir;
  late final Directory harnessDir;
  late final Directory workDir;
  late final Directory fpathDir;
  late final Directory xdgConfigDir;
  late final Directory homeDir;

  String get exePath =>
      p.join(binDir.path, Platform.isWindows ? '$_exeName.exe' : _exeName);

  /// The generated script for [shell]; PowerShell requires a `.ps1` file.
  String scriptPath(final String shell) => p.join(
    scriptDir.path,
    shell == 'powershell' ? '$_exeName.ps1' : '$_exeName.$shell',
  );

  String harnessPath(final String name) => p.join(harnessDir.path, name);

  Future<void> setUp() async {
    root = Directory.systemTemp.createTempSync('completion_shell_test_');
    binDir = Directory(p.join(root.path, 'bin'))..createSync();
    scriptDir = Directory(p.join(root.path, 'scripts'))..createSync();
    harnessDir = Directory(p.join(root.path, 'harness'))..createSync();
    workDir = Directory(p.join(root.path, 'work'))..createSync();
    fpathDir = Directory(p.join(root.path, 'fpath'))..createSync();
    homeDir = Directory(p.join(root.path, 'home'))..createSync();
    xdgConfigDir = Directory(p.join(root.path, 'xdg_config'))..createSync();

    Directory(p.join(workDir.path, 'sub')).createSync();
    for (final name in ['f.txt', 'a.yaml', 'b.yml']) {
      File(p.join(workDir.path, name)).createSync();
    }

    await _compileFixture();
    await _generateScripts();
    _writeHarnesses();
  }

  void tearDown() {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Best effort.
    }
  }

  Future<void> _compileFixture() async {
    final fixture = p.join(
      p.dirname(Platform.script.toFilePath()),
      'fixtures',
      'completion_cli.dart',
    );
    final source = File(fixture).existsSync()
        ? fixture
        : p.join(
            Directory.current.path,
            'test',
            'command',
            'completion',
            'fixtures',
            'completion_cli.dart',
          );
    final result = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'exe',
      source,
      '-o',
      exePath,
    ]);
    if (result.exitCode != 0) {
      fail('Compiling the fixture failed:\n${result.stdout}\n${result.stderr}');
    }
  }

  Future<void> _generateScripts() async {
    for (final shell in ['bash', 'zsh', 'fish', 'powershell']) {
      final result = await run(exePath, ['completion', shell]);
      File(scriptPath(shell)).writeAsStringSync(result.stdout);
    }
    File(p.join(fpathDir.path, '_$_exeName')).writeAsStringSync(
      File(scriptPath('zsh')).readAsStringSync(),
    );
    final specs = Directory(p.join(xdgConfigDir.path, 'carapace', 'specs'))
      ..createSync(recursive: true);
    final spec = await run(exePath, ['completion', 'carapace']);
    File(p.join(specs.path, '$_exeName.yaml')).writeAsStringSync(spec.stdout);
  }

  void _writeHarnesses() {
    File(harnessPath('bash_harness.sh')).writeAsStringSync(_bashHarness);
    File(harnessPath('zsh_harness.zsh')).writeAsStringSync(_zshHarness);
    File(harnessPath('zsh_init.zsh')).writeAsStringSync(_zshInit);
    File(harnessPath('ps_harness.ps1')).writeAsStringSync(_powershellHarness);
  }

  /// Runs [executable] in the working directory with the fixture
  /// executable on the PATH, failing the test on a non-zero exit code
  /// when [expectSuccess] is set.
  Future<_ProcessOutput> run(
    final String executable,
    final List<String> arguments, {
    final Map<String, String> environment = const {},
    final bool expectSuccess = true,
  }) async {
    final separator = Platform.isWindows ? ';' : ':';
    final path = '${binDir.path}$separator${Platform.environment['PATH']}';
    // On Windows the variable may be spelled `Path`; replace it rather than
    // adding a second, differently cased entry.
    final processEnvironment = <String, String>{...Platform.environment}
      ..removeWhere((final key, final _) => key.toUpperCase() == 'PATH')
      ..addAll({
        'PATH': path,
        'HOME': homeDir.path,
        'TERM': 'xterm',
        'XDG_CONFIG_HOME': xdgConfigDir.path,
        'XDG_CACHE_HOME': p.join(root.path, 'xdg_cache'),
        ...environment,
      });
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workDir.path,
      environment: processEnvironment,
    );
    final stdout = process.stdout.transform(utf8.decoder).join();
    final stderr = process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        process.kill();
        fail('$executable ${arguments.join(' ')} timed out');
      },
    );
    final output = _ProcessOutput(await stdout, await stderr, exitCode);
    if (expectSuccess && exitCode != 0) {
      fail(
        '$executable ${arguments.join(' ')} failed with exit code $exitCode:\n'
        '${output.stdout}\n${output.stderr}',
      );
    }
    return output;
  }
}

/// Sources the script and calls the completion function the way Bash does,
/// printing COMPREPLY one entry per line.
/// Arguments: the script, then the words after the executable name;
/// the last word is the one being completed.
const _bashHarness = r'''
script=$1; shift
source "$script" || exit 1
COMP_WORDS=(comptool "$@")
COMP_CWORD=$(( ${#COMP_WORDS[@]} - 1 ))
COMP_LINE="${COMP_WORDS[*]}"
COMP_POINT=${#COMP_LINE}
__comptool_complete comptool "${COMP_WORDS[COMP_CWORD]}" "${COMP_WORDS[COMP_CWORD-1]}"
printf '%s\n' "${COMPREPLY[@]}"
''';

/// Sourced in the interactive Zsh under test: sets up the completion system
/// with the script either sourced or autoloaded from fpath, and binds a key
/// that saves the command line buffer to a file.
const _zshInit = r'''
if [[ $COMPLETION_INSTALL == fpath ]]; then fpath=("$COMPLETION_FPATH" $fpath); fi
autoload -Uz compinit
compinit -u -d "$ZSH_COMPDUMP"
if [[ $COMPLETION_INSTALL != fpath ]]; then source "$COMPLETION_SCRIPT"; fi
stty columns 200 rows 50
LISTMAX=10000
zstyle ':completion:*' menu no
zstyle ':completion:*' list-colors ''
__dump() { print -r -- "$BUFFER" > "$ZSH_BUFFER_FILE"; zle kill-whole-line; zle accept-line }
zle -N __dump
bindkey '^X^P' __dump
''';

/// Runs an interactive Zsh in a pseudo terminal, types the given line
/// followed by TAB, and prints the resulting buffer and terminal output.
const _zshHarness = r'''
zmodload zsh/zpty || { print 'zsh/zpty unavailable'; exit 2 }
export PS1='PROMPT> '
rm -f "$ZSH_BUFFER_FILE"
zpty z 'zsh -f -i'
zpty -r z log '*PROMPT>*' || { print 'no prompt'; exit 1 }
zpty -w z "source '$ZSH_INIT'"
zpty -r z log '*PROMPT>*' || { print 'no prompt after init'; exit 1 }
zpty -n -w z "$1"$'\t'$'\C-x\C-p'
zpty -r z log '*PROMPT>*' || { print 'no prompt after completion'; exit 1 }
zpty -d z
print -r -- "BUFFER:$(cat "$ZSH_BUFFER_FILE" 2>/dev/null)"
print -r -- "LOG:$log"
''';

/// Loads the script and completes the line with TabExpansion2,
/// printing one tab-separated line per completion result.
const _powershellHarness = r'''
param([string]$Script, [string]$Line)
$ErrorActionPreference = 'Stop'
. $Script
$result = TabExpansion2 -inputScript $Line -cursorColumn $Line.Length
foreach ($m in $result.CompletionMatches) {
    "$($m.CompletionText)`t$($m.ListItemText)`t$($m.ResultType)`t$($m.ToolTip)"
}
''';
