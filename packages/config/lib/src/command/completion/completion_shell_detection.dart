import 'dart:io' show Platform, Process, pid;

import 'completion_shell.dart';

/// Determines the shell that the user most likely runs the program from,
/// or null if there is no such [CompletionShell].
///
/// The alternatives are tried in this order:
/// 1. The nearest ancestor process that is a supported shell which the user
///    types in. A shell that runs a script or a command (`bash wrapper.sh`,
///    `sh -c ...`) is passed over, so that a wrapper script of the program
///    does not hide the shell it was started from.
/// 2. The user's login shell, from the `SHELL` environment variable.
/// 3. PowerShell on Windows, where the ancestor processes are not inspected.
///
/// [CompletionShell.carapace] is a completion framework rather than a shell
/// and is never detected.
///
/// [environment] defaults to the environment of the process, and
/// [isWindows] to the platform it runs on. [ancestorCommandLines] are the
/// command lines (the executable followed by its arguments) of the ancestor
/// processes, nearest first. By default they are read with `ps`.
CompletionShell? detectCompletionShell({
  final Map<String, String>? environment,
  final Iterable<List<String>>? ancestorCommandLines,
  final bool? isWindows,
}) {
  final windows = isWindows ?? Platform.isWindows;
  final commandLines =
      ancestorCommandLines ??
      (windows ? const <List<String>>[] : _ancestorCommandLines());
  for (final commandLine in commandLines) {
    final shell = _typedInShell(commandLine);
    if (shell != null) return shell;
  }

  final loginShell = (environment ?? Platform.environment)['SHELL'];
  final shell = loginShell == null ? null : _shellOfExecutable(loginShell);
  return shell ?? (windows ? CompletionShell.powershell : null);
}

/// The shell of [commandLine], unless it runs a script or a command:
/// then it has an operand, i.e. an argument that is not an option.
CompletionShell? _typedInShell(final List<String> commandLine) {
  if (commandLine.isEmpty) return null;
  final hasOperand = commandLine
      .skip(1)
      .any((final argument) => !argument.startsWith('-'));
  return hasOperand ? null : _shellOfExecutable(commandLine.first);
}

/// The shell run by [executable], which may be a path, the `-zsh` form of
/// a login shell, a versioned name such as `zsh-5.9`, or a Windows `.exe`.
CompletionShell? _shellOfExecutable(final String executable) {
  final name = executable.split(RegExp(r'[/\\]')).last.toLowerCase();
  final match = _shellName.firstMatch(name);
  return switch (match?[1]) {
    'bash' => CompletionShell.bash,
    'zsh' => CompletionShell.zsh,
    'fish' => CompletionShell.fish,
    'pwsh' || 'powershell' => CompletionShell.powershell,
    _ => null,
  };
}

final _shellName = RegExp(
  r'^-?(bash|zsh|fish|pwsh|powershell)(-[0-9.]+)?(\.exe)?$',
);

/// More ancestors than this are not inspected.
const _maxAncestors = 16;

/// The command lines of the ancestor processes, nearest first.
///
/// Lazy, so that no more ancestors are inspected than needed.
Iterable<List<String>> _ancestorCommandLines() sync* {
  var parent = _processInfo(pid)?.parentPid;
  for (var i = 0; i < _maxAncestors && parent != null && parent > 0; i++) {
    final process = _processInfo(parent);
    if (process == null) return;
    yield process.commandLine;
    parent = process.parentPid;
  }
}

/// The parent and the command line of the process [processId],
/// or null if they can't be read.
///
/// The command line is split at whitespace, which is good enough to tell
/// options from operands.
({int parentPid, List<String> commandLine})? _processInfo(final int processId) {
  final String output;
  try {
    final result = Process.runSync('ps', [
      '-o',
      'ppid=,args=',
      '-p',
      '$processId',
    ]);
    if (result.exitCode != 0) return null;
    output = result.stdout as String;
  } on Exception {
    // `ps` is missing, not permitted, or printed undecodable text.
    return null;
  }

  final lines = output.trim().split('\n');
  if (lines.length != 1) return null;
  final fields = lines.single.trim().split(RegExp(r'\s+'));
  final parentPid = int.tryParse(fields.first);
  if (parentPid == null) return null;
  return (parentPid: parentPid, commandLine: fields.sublist(1));
}
