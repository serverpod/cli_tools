/// Settings for the built-in shell completion support of a `CommandRunner`.
///
/// Completion is enabled by default. It adds:
/// - a hidden `__complete` request handler that the shell completion scripts
///   call to obtain the completion alternatives,
/// - a `completion <shell>` subcommand that prints the completion script
///   for a shell, when the runner has subcommands,
/// - a `--completion <shell>` global option that does the same, when the
///   runner has no subcommands.
///
/// The generated scripts carry their installation instructions in their
/// comment header, so that they are available for both kinds of runners.
class CompletionSettings {
  /// Whether completion support is enabled.
  final bool enabled;

  /// Whether the `completion` subcommand is hidden from the usage help.
  final bool hideCommand;

  /// Whether the process exits (with exit code 0) as soon as a completion
  /// response or a completion script has been written. Defaults to true.
  ///
  /// The completion output must be the only output on stdout: anything the
  /// program prints after `CommandRunner.runner()` returns would corrupt the
  /// response read by the shell, or the script being sourced. Exiting
  /// prevents that without requiring the program to check what was run.
  ///
  /// Set to false to make `runner()` return null instead, e.g. when running
  /// the runner in-process (such as in tests). The output sink is flushed
  /// before exiting if it is an `IOSink` (the default is `stdout`).
  final bool exitAfterResponse;

  const CompletionSettings({
    this.enabled = true,
    this.hideCommand = false,
    this.exitAfterResponse = true,
  });

  /// Disables completion support entirely.
  static const CompletionSettings disabled = CompletionSettings(enabled: false);
}
