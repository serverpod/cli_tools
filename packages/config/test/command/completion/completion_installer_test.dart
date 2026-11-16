import 'dart:io';

import 'package:config/command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _script = '# the completion script\n';

void main() {
  late Directory home;

  /// A path below the home directory, in POSIX style like the installers
  /// under test, which install for Linux or macOS.
  String inHome(final String relativePath) => '${home.path}/$relativePath';

  CompletionInstaller newInstaller({
    final Map<String, String> environment = const {},
    final String operatingSystem = 'linux',
  }) {
    return CompletionInstaller(
      environment: {'HOME': home.path, ...environment},
      operatingSystem: operatingSystem,
    );
  }

  List<CompletionInstallStep> plan(
    final CompletionInstaller installer,
    final CompletionShell shell, {
    final String name = 'mytool',
  }) {
    return installer.plan(
      shell,
      name: name,
      script: _script,
      executableName: 'mytool',
    );
  }

  void install(
    final CompletionInstaller installer,
    final CompletionShell shell,
  ) {
    for (final step in plan(installer, shell)) {
      step.perform();
    }
  }

  List<String> descriptions(final List<CompletionInstallStep> steps) => [
    for (final step in steps) step.description,
  ];

  setUp(() {
    home = Directory.systemTemp.createTempSync('completion_installertest_');
  });

  tearDown(() => home.deleteSync(recursive: true));

  group('Given an installer for an empty home directory on Linux', () {
    test('when planning the Bash installation '
        'then the script is written to the bash-completion user directory '
        'and sourced from a new .bashrc', () {
      final script = inHome('.local/share/bash-completion/completions/mytool');
      expect(descriptions(plan(newInstaller(), CompletionShell.bash)), [
        'Create directory ${p.posix.dirname(script)}',
        'Write $script',
        'Create ${inHome('.bashrc')}:\n'
            '  # mytool shell completion, '
            'added by `mytool completion install`.\n'
            "  [ -r '$script' ] && source '$script'",
      ]);
    });

    test('when planning the Zsh installation '
        'then the script is written as a function file '
        'and sourced from a new .zshrc after ensuring compinit', () {
      final script = inHome('.local/share/zsh/site-functions/_mytool');
      expect(descriptions(plan(newInstaller(), CompletionShell.zsh)), [
        'Create directory ${p.posix.dirname(script)}',
        'Write $script',
        'Create ${inHome('.zshrc')}:\n'
            '  # mytool shell completion, '
            'added by `mytool completion install`.\n'
            r'  (( $+functions[compdef] )) || '
            '{ autoload -Uz compinit && compinit; }\n'
            "  [[ -r '$script' ]] && source '$script'",
      ]);
    });

    test('when planning the Fish installation '
        'then the script is written to the Fish completions directory '
        'and no startup file is changed', () {
      final script = inHome('.config/fish/completions/mytool.fish');
      expect(descriptions(plan(newInstaller(), CompletionShell.fish)), [
        'Create directory ${p.posix.dirname(script)}',
        'Write $script',
      ]);
    });

    test('when planning the PowerShell installation '
        'then the script is written next to the profile, which loads it, '
        'and their directory is created once', () {
      final script = inHome('.config/powershell/Completions/mytool.ps1');
      final profile = inHome(
        '.config/powershell/Microsoft.PowerShell_profile.ps1',
      );
      expect(descriptions(plan(newInstaller(), CompletionShell.powershell)), [
        'Create directory ${p.posix.dirname(script)}',
        'Write $script',
        'Create $profile:\n'
            '  # mytool shell completion, '
            'added by `mytool completion install`.\n'
            "  if (Test-Path -LiteralPath '$script') { . '$script' }",
      ]);
    });

    test('when planning the Carapace installation '
        'then the spec is written to the Carapace specs directory '
        'and no startup file is changed', () {
      final spec = inHome('.config/carapace/specs/mytool.yaml');
      expect(descriptions(plan(newInstaller(), CompletionShell.carapace)), [
        'Create directory ${p.posix.dirname(spec)}',
        'Write $spec',
      ]);
    });

    test('when planning an installation for another command name '
        'then the script is named after that command', () {
      final steps = plan(newInstaller(), CompletionShell.zsh, name: 'mywrap');
      expect(
        descriptions(steps),
        contains(
          'Write ${inHome('.local/share/zsh/site-functions/_mywrap')}',
        ),
      );
      expect(
        descriptions(steps).last,
        contains(
          '# mywrap shell completion, added by `mytool completion install`.',
        ),
      );
    });

    for (final shell in CompletionShell.values) {
      test('when planning the ${shell.displayName} installation '
          'then nothing is created', () {
        plan(newInstaller(), shell);
        expect(home.listSync(), isEmpty);
      });

      test('when performing the ${shell.displayName} installation '
          'then the script is at the script path', () {
        final installer = newInstaller();
        install(installer, shell);
        expect(
          File(installer.scriptPath(shell, 'mytool')).readAsStringSync(),
          _script,
        );
      });
    }

    test('when performing the Bash installation '
        'then the startup file has the comment and the line that sources '
        'the script', () {
      install(newInstaller(), CompletionShell.bash);
      final script = inHome('.local/share/bash-completion/completions/mytool');
      expect(
        File(inHome('.bashrc')).readAsStringSync(),
        '# mytool shell completion, added by `mytool completion install`.\n'
        "[ -r '$script' ] && source '$script'\n",
      );
    });

    test('when the home directory has a quote in its path '
        'then the script path is quoted for the shell', () {
      final quoted = Directory("${home.path}/it's")..createSync();
      final installer = CompletionInstaller(
        environment: {'HOME': quoted.path},
        operatingSystem: 'linux',
      );
      install(installer, CompletionShell.bash);
      expect(
        File('${quoted.path}/.bashrc').readAsStringSync(),
        contains(
          r"[ -r '"
          '${home.path}'
          r"/it'\''s/.local/",
        ),
      );
    });
  });

  group('Given an installer for a home directory with startup files', () {
    test('when the startup file ends with a newline '
        'then the lines are appended after an empty line', () {
      File(inHome('.bashrc')).writeAsStringSync('alias ll="ls -l"\n');
      final steps = plan(newInstaller(), CompletionShell.bash);
      expect(steps.last.description, startsWith('Append to '));
      for (final step in steps) {
        step.perform();
      }
      expect(
        File(inHome('.bashrc')).readAsStringSync(),
        startsWith('alias ll="ls -l"\n\n# mytool shell completion, '),
      );
    });

    test('when the startup file does not end with a newline '
        'then the lines are appended after an empty line', () {
      File(inHome('.zshrc')).writeAsStringSync('alias ll="ls -l"');
      install(newInstaller(), CompletionShell.zsh);
      expect(
        File(inHome('.zshrc')).readAsStringSync(),
        startsWith('alias ll="ls -l"\n\n# mytool shell completion, '),
      );
    });

    test('when the startup file is empty '
        'then the lines are written from its start', () {
      File(inHome('.zshrc')).writeAsStringSync('');
      install(newInstaller(), CompletionShell.zsh);
      expect(
        File(inHome('.zshrc')).readAsStringSync(),
        startsWith('# mytool shell completion, '),
      );
    });

    test('when the startup file is not valid UTF-8 '
        'then the lines are appended and its content is kept', () {
      File(inHome('.bashrc')).writeAsBytesSync([0x23, 0xff, 0xfe, 0x0a]);
      install(newInstaller(), CompletionShell.bash);
      final bytes = File(inHome('.bashrc')).readAsBytesSync();
      expect(bytes.sublist(0, 4), [0x23, 0xff, 0xfe, 0x0a]);
      expect(String.fromCharCodes(bytes.sublist(4)), contains('source'));
    });

    group('when the installation has been performed already', () {
      late CompletionInstaller installer;
      late String startupFileContent;

      setUp(() {
        installer = newInstaller();
        File(inHome('.zshrc')).writeAsStringSync('alias ll="ls -l"\n');
        install(installer, CompletionShell.zsh);
        startupFileContent = File(inHome('.zshrc')).readAsStringSync();
      });

      test('then the plan only writes the script '
          'and notes that the startup file is kept', () {
        expect(descriptions(plan(installer, CompletionShell.zsh)), [
          'Write ${inHome('.local/share/zsh/site-functions/_mytool')}',
          'Keep ${inHome('.zshrc')}, it already loads the script',
        ]);
      });

      test('then performing it again leaves the startup file unchanged', () {
        install(installer, CompletionShell.zsh);
        expect(File(inHome('.zshrc')).readAsStringSync(), startupFileContent);
      });

      test('then installing for another command name appends its lines', () {
        final steps = plan(installer, CompletionShell.zsh, name: 'mywrap');
        expect(steps.last.description, startsWith('Append to '));
      });
    });
  });

  group('Given an installer with XDG and shell directory variables', () {
    test('when XDG_DATA_HOME is set '
        'then the Bash and Zsh scripts are installed below it', () {
      final installer = newInstaller(environment: {'XDG_DATA_HOME': '/data'});
      expect(
        installer.scriptPath(CompletionShell.bash, 'mytool'),
        '/data/bash-completion/completions/mytool',
      );
      expect(
        installer.scriptPath(CompletionShell.zsh, 'mytool'),
        '/data/zsh/site-functions/_mytool',
      );
    });

    test('when BASH_COMPLETION_USER_DIR is set '
        'then the Bash script is installed below it', () {
      final installer = newInstaller(
        environment: {
          'XDG_DATA_HOME': '/data',
          'BASH_COMPLETION_USER_DIR': '/bash-completion',
        },
      );
      expect(
        installer.scriptPath(CompletionShell.bash, 'mytool'),
        '/bash-completion/completions/mytool',
      );
    });

    test('when XDG_CONFIG_HOME is set '
        'then the Fish script, the Carapace spec and the PowerShell profile '
        'are below it', () {
      final installer = newInstaller(
        environment: {'XDG_CONFIG_HOME': '/config'},
      );
      expect(
        installer.scriptPath(CompletionShell.fish, 'mytool'),
        '/config/fish/completions/mytool.fish',
      );
      expect(
        installer.scriptPath(CompletionShell.carapace, 'mytool'),
        '/config/carapace/specs/mytool.yaml',
      );
      expect(
        installer.startupFilePath(CompletionShell.powershell),
        '/config/powershell/Microsoft.PowerShell_profile.ps1',
      );
    });

    test('when an XDG variable is empty then it is ignored', () {
      final installer = newInstaller(environment: {'XDG_CONFIG_HOME': ''});
      expect(
        installer.scriptPath(CompletionShell.fish, 'mytool'),
        inHome('.config/fish/completions/mytool.fish'),
      );
    });

    test('when ZDOTDIR is set then its .zshrc is the Zsh startup file', () {
      final installer = newInstaller(environment: {'ZDOTDIR': '/zdotdir'});
      expect(
        installer.startupFilePath(CompletionShell.zsh),
        '/zdotdir/.zshrc',
      );
    });

    test('when asking for the startup file of Fish and Carapace '
        'then there is none', () {
      expect(newInstaller().startupFilePath(CompletionShell.fish), isNull);
      expect(newInstaller().startupFilePath(CompletionShell.carapace), isNull);
    });
  });

  group('Given an installer for macOS', () {
    CompletionInstaller macInstaller() =>
        newInstaller(operatingSystem: 'macos');

    test('when the home directory has no Bash startup file '
        'then .bash_profile is the Bash startup file', () {
      expect(
        macInstaller().startupFilePath(CompletionShell.bash),
        inHome('.bash_profile'),
      );
    });

    test('when the home directory has a .profile but no .bash_profile '
        'then .profile is the Bash startup file, since a new .bash_profile '
        'would replace it', () {
      File(inHome('.profile')).createSync();
      File(inHome('.bashrc')).createSync();
      expect(
        macInstaller().startupFilePath(CompletionShell.bash),
        inHome('.profile'),
      );
    });

    test('when the home directory has a .bash_login and a .profile '
        'then .bash_login is the Bash startup file', () {
      File(inHome('.profile')).createSync();
      File(inHome('.bash_login')).createSync();
      expect(
        macInstaller().startupFilePath(CompletionShell.bash),
        inHome('.bash_login'),
      );
    });

    test('when asking for the Carapace spec path '
        'then it is in the Application Support directory', () {
      expect(
        macInstaller().scriptPath(CompletionShell.carapace, 'mytool'),
        inHome('Library/Application Support/carapace/specs/mytool.yaml'),
      );
    });
  });

  group('Given an installer for Windows', () {
    CompletionInstaller windowsInstaller({
      final Map<String, String> environment = const {
        'USERPROFILE': r'C:\Users\me',
      },
      final String? profile,
    }) {
      return CompletionInstaller(
        environment: environment,
        operatingSystem: 'windows',
        powerShellProfile: () => profile,
      );
    }

    test('when PowerShell reports its profile '
        'then the profile is the startup file '
        'and the script is installed next to it', () {
      const profile =
          r'C:\Users\me\OneDrive\Documents\PowerShell'
          r'\Microsoft.PowerShell_profile.ps1';
      final installer = windowsInstaller(profile: profile);
      expect(installer.startupFilePath(CompletionShell.powershell), profile);
      expect(
        installer.scriptPath(CompletionShell.powershell, 'mytool'),
        r'C:\Users\me\OneDrive\Documents\PowerShell\Completions\mytool.ps1',
      );
    });

    test('when PowerShell does not report its profile '
        'then the default profile of PowerShell is the startup file', () {
      expect(
        windowsInstaller().startupFilePath(CompletionShell.powershell),
        r'C:\Users\me\Documents\PowerShell\Microsoft.PowerShell_profile.ps1',
      );
    });

    test('when the script path has a quote '
        'then it is quoted for PowerShell in the profile', () {
      final steps =
          windowsInstaller(
            profile: r"C:\Users\O'Hara\Documents\PowerShell\profile.ps1",
          ).plan(
            CompletionShell.powershell,
            name: 'mytool',
            script: _script,
            executableName: 'mytool',
          );
      expect(
        steps.last.description,
        contains(
          r"if (Test-Path -LiteralPath 'C:\Users\O''Hara\Documents"
          r"\PowerShell\Completions\mytool.ps1') "
          r"{ . 'C:\Users\O''Hara\Documents"
          r"\PowerShell\Completions\mytool.ps1' }",
        ),
      );
    });

    test('when asking for the Carapace spec path '
        'then it is in the roaming application data directory', () {
      expect(
        windowsInstaller(
          environment: const {
            'USERPROFILE': r'C:\Users\me',
            'APPDATA': r'D:\Roaming',
          },
        ).scriptPath(CompletionShell.carapace, 'mytool'),
        r'D:\Roaming\carapace\specs\mytool.yaml',
      );
    });

    test('when HOME is set, as in Git Bash, '
        'then the Bash startup file is in that directory', () {
      expect(
        windowsInstaller(
          environment: const {
            'HOME': r'C:\Users\gitbash',
            'USERPROFILE': r'C:\Users\me',
          },
        ).startupFilePath(CompletionShell.bash),
        r'C:\Users\gitbash\.bashrc',
      );
    });
  });

  group('Given an installer without a home directory', () {
    test('when planning an installation on Linux '
        'then it fails naming the HOME variable', () {
      final installer = CompletionInstaller(
        environment: const {},
        operatingSystem: 'linux',
      );
      expect(
        () => plan(installer, CompletionShell.zsh),
        throwsA(
          isA<FileSystemException>().having(
            (final e) => e.message,
            'message',
            contains('HOME is not set'),
          ),
        ),
      );
    });

    test('when planning an installation on Windows '
        'then it fails naming the USERPROFILE variable', () {
      final installer = CompletionInstaller(
        environment: const {},
        operatingSystem: 'windows',
        powerShellProfile: () => null,
      );
      expect(
        () => plan(installer, CompletionShell.powershell),
        throwsA(
          isA<FileSystemException>().having(
            (final e) => e.message,
            'message',
            contains('USERPROFILE is not set'),
          ),
        ),
      );
    });

    test('when all locations are given by other variables '
        'then the home directory is not needed', () {
      final installer = CompletionInstaller(
        environment: const {'XDG_CONFIG_HOME': '/config'},
        operatingSystem: 'linux',
      );
      expect(
        installer.scriptPath(CompletionShell.fish, 'mytool'),
        '/config/fish/completions/mytool.fish',
      );
    });
  });
}
