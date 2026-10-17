import 'scripts/bash_completion_script.dart';
import 'scripts/carapace_completion_spec.dart';
import 'scripts/fish_completion_script.dart';
import 'scripts/powershell_completion_script.dart';
import 'scripts/zsh_completion_script.dart';

/// The shells and completion frameworks for which completion scripts
/// can be generated.
enum CompletionShell {
  bash('Bash'),
  zsh('Zsh'),
  fish('Fish'),
  powershell('PowerShell'),
  carapace('Carapace');

  /// The display name.
  final String displayName;

  const CompletionShell(this.displayName);

  /// Generates the completion script (or spec) for [executableName].
  ///
  /// The script is independent of the commands and options of the
  /// executable: it asks the executable for the completion alternatives
  /// via the `__complete` request, so it needs to be installed only once.
  ///
  /// [description] is a short description of the executable, included
  /// where the format supports it.
  String script(final String executableName, {final String? description}) {
    return switch (this) {
      CompletionShell.bash => bashCompletionScript(executableName),
      CompletionShell.zsh => zshCompletionScript(executableName),
      CompletionShell.fish => fishCompletionScript(executableName),
      CompletionShell.powershell => powershellCompletionScript(executableName),
      CompletionShell.carapace => carapaceCompletionSpec(
        executableName,
        description: description,
      ),
    };
  }

  /// The command that installs the completion script for this shell,
  /// e.g. `source <(mycli completion bash)`.
  ///
  /// See [installLocation] for where to run or add it.
  String installCommand(final String executableName) {
    final exe = executableName;
    return switch (this) {
      CompletionShell.bash => 'source <($exe completion bash)',
      CompletionShell.zsh => 'source <($exe completion zsh)',
      CompletionShell.fish =>
        '$exe completion fish > ~/.config/fish/completions/$exe.fish',
      CompletionShell.powershell =>
        '$exe completion powershell | Out-String | Invoke-Expression',
      CompletionShell.carapace =>
        '$exe completion carapace > ~/.config/carapace/specs/$exe.yaml',
    };
  }

  /// The shell startup file to add [installCommand] to,
  /// or null if the command is run once instead.
  String? get installLocation => switch (this) {
    CompletionShell.bash => '~/.bashrc',
    CompletionShell.zsh => '~/.zshrc, after compinit',
    CompletionShell.powershell => r'$PROFILE',
    CompletionShell.fish || CompletionShell.carapace => null,
  };

  /// One-line installation instruction for this shell:
  /// the [installCommand], followed by the [installLocation] as a comment.
  String installInstruction(final String executableName) {
    final command = installCommand(executableName);
    final location = installLocation;
    return location == null ? command : '$command  # in $location';
  }

  /// Longer installation instructions for this shell, including
  /// alternative ways to install the script where available.
  String installInstructions(final String executableName) {
    final exe = executableName;
    final command = installCommand(exe);
    return switch (this) {
      CompletionShell.bash =>
        'Add to ~/.bashrc:\n'
            '  $command\n'
            'or save it once:\n'
            '  $exe completion bash > /etc/bash_completion.d/$exe',
      CompletionShell.zsh =>
        'Add to ~/.zshrc (after compinit):\n'
            '  $command\n'
            'or save it once to a directory in \$fpath:\n'
            '  $exe completion zsh > "\${fpath[1]}/_$exe"',
      CompletionShell.fish => 'Save it once:\n  $command',
      CompletionShell.powershell =>
        'Add to your PowerShell profile (\$PROFILE):\n  $command',
      CompletionShell.carapace =>
        'Save it once to the Carapace specs directory '
            '(shown by `carapace --help`):\n'
            '  $command\n'
            '(macOS: ~/Library/Application Support/carapace/specs/$exe.yaml)',
    };
  }
}

/// Short installation instructions for all shells, one line per shell,
/// under an `Installation:` heading. Used in the usage of the
/// `completion` command.
String completionInstallationOverview(final String executableName) {
  const labelWidth = 12;
  return [
    'Installation:',
    for (final shell in CompletionShell.values)
      '  ${'${shell.displayName}:'.padRight(labelWidth)} '
          '${shell.installInstruction(executableName)}',
  ].join('\n');
}

/// A name for [executableName] that is safe to use in shell identifiers:
/// letters, digits and underscores only.
String shellIdentifier(final String executableName) {
  final sanitized = executableName.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
  if (sanitized.isEmpty || RegExp(r'^[0-9]').hasMatch(sanitized)) {
    return '_$sanitized';
  }
  return sanitized;
}
