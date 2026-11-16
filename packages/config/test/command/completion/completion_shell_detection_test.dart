import 'package:config/command.dart';
import 'package:test/test.dart';

/// Detects the shell from [ancestors], the command lines of the ancestor
/// processes (nearest first), and the login shell.
CompletionShell? _detect(
  final List<List<String>> ancestors, {
  final String? loginShell,
  final bool isWindows = false,
}) {
  return detectCompletionShell(
    environment: {'SHELL': ?loginShell},
    ancestorCommandLines: ancestors,
    isWindows: isWindows,
  );
}

void main() {
  group('Given a program started from a shell the user types in', () {
    const shells = <(List<String>, CompletionShell)>[
      (['bash'], CompletionShell.bash),
      (['-bash'], CompletionShell.bash),
      (['/opt/homebrew/bin/bash'], CompletionShell.bash),
      (['-/opt/homebrew/bin/bash', '--posix'], CompletionShell.bash),
      (['bash', '--login', '-i'], CompletionShell.bash),
      (['-zsh'], CompletionShell.zsh),
      (['/bin/zsh', '-l'], CompletionShell.zsh),
      (['/usr/bin/zsh-5.9'], CompletionShell.zsh),
      (['fish'], CompletionShell.fish),
      (['/usr/local/bin/fish', '--private'], CompletionShell.fish),
      (['pwsh'], CompletionShell.powershell),
      (['/usr/bin/pwsh', '-NoLogo'], CompletionShell.powershell),
      ([r'C:\Program Files\PowerShell\7\pwsh.exe'], CompletionShell.powershell),
      (['PowerShell.EXE', '-NoProfile'], CompletionShell.powershell),
    ];
    for (final (commandLine, shell) in shells) {
      test('when the parent process is `${commandLine.join(' ')}` '
          'then ${shell.displayName} is detected', () {
        expect(_detect([commandLine]), shell);
      });
    }

    test('when the login shell is another shell '
        'then the shell the program is started from is detected', () {
      expect(
        _detect([
          ['fish'],
        ], loginShell: '/bin/zsh'),
        CompletionShell.fish,
      );
    });

    test('when that shell was started from another shell '
        'then the nearest one is detected', () {
      expect(
        _detect([
          ['fish'],
          ['-zsh'],
        ]),
        CompletionShell.fish,
      );
    });
  });

  group('Given a program started through other processes', () {
    test('when the parent process is not a shell '
        'then the shell above it is detected', () {
      expect(
        _detect([
          ['dart', 'run', 'bin/mytool.dart'],
          ['-zsh'],
        ]),
        CompletionShell.zsh,
      );
    });

    test('when the parent process is a shell running a wrapper script '
        'then the shell above it is detected', () {
      expect(
        _detect([
          ['bash', '/usr/local/bin/mywrap', 'completion'],
          ['fish'],
        ]),
        CompletionShell.fish,
      );
    });

    test('when the parent process is a shell running a command '
        'then the shell above it is detected', () {
      expect(
        _detect([
          ['zsh', '-c', 'mytool', 'completion'],
          ['-bash'],
        ]),
        CompletionShell.bash,
      );
    });

    test('when the parent process is a shell without completion support '
        'then the shell above it is detected', () {
      expect(
        _detect([
          ['/bin/sh', '/usr/local/bin/mywrap'],
          ['tcsh'],
          ['-zsh'],
        ]),
        CompletionShell.zsh,
      );
    });

    test('when a process has no command line '
        'then the shell above it is detected', () {
      expect(
        _detect([
          [],
          ['-zsh'],
        ]),
        CompletionShell.zsh,
      );
    });
  });

  group('Given a program without a shell the user types in above it', () {
    const ancestors = [
      ['dart', 'test'],
      ['bash', '-c', 'dart test'],
      ['/sbin/launchd'],
    ];

    for (final MapEntry(key: loginShell, value: shell) in {
      '/bin/bash': CompletionShell.bash,
      '/bin/zsh': CompletionShell.zsh,
      '/opt/homebrew/bin/fish': CompletionShell.fish,
      '/usr/bin/pwsh': CompletionShell.powershell,
    }.entries) {
      test('when the login shell is $loginShell '
          'then ${shell.displayName} is detected', () {
        expect(_detect(ancestors, loginShell: loginShell), shell);
      });
    }

    test('when the login shell has no completion support '
        'then no shell is detected', () {
      expect(_detect(ancestors, loginShell: '/bin/tcsh'), isNull);
    });

    test('when there is no login shell then no shell is detected', () {
      expect(_detect(ancestors), isNull);
    });
  });

  group('Given a program on Windows', () {
    test('when there is no login shell then PowerShell is detected', () {
      expect(_detect([], isWindows: true), CompletionShell.powershell);
    });

    test('when the login shell is Bash, as in Git Bash, '
        'then Bash is detected', () {
      expect(
        _detect([], loginShell: r'C:\Program Files\Git\usr\bin\bash.exe'),
        CompletionShell.bash,
      );
    });

    test('when the login shell has no completion support '
        'then PowerShell is detected', () {
      expect(
        _detect([], loginShell: '/usr/bin/sh', isWindows: true),
        CompletionShell.powershell,
      );
    });
  });

  group('Given the environment and the processes of the test', () {
    test('when detecting the shell then it completes normally', () {
      expect(detectCompletionShell, returnsNormally);
    });
  });
}
