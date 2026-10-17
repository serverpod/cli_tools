## Shell completion

The `CommandRunner` in `package:config/command.dart` has built-in command line
completion for Bash, Zsh, Fish, PowerShell and the
[Carapace](https://carapace.sh) completion framework. It is enabled by default
and requires no work from the CLI developer.

End users install the completion once. A `CommandRunner` with subcommands gets
a `completion` subcommand that prints the script for a shell:

```sh
# Bash: add to ~/.bashrc
source <(mycli completion bash)
# Zsh: add to ~/.zshrc after compinit, or save as _mycli in a directory on $fpath
source <(mycli completion zsh)
# Fish
mycli completion fish > ~/.config/fish/completions/mycli.fish
# PowerShell: add to $PROFILE
mycli completion powershell | Out-String | Invoke-Expression
# Carapace: save to the specs directory shown by `carapace --help`
mycli completion carapace > ~/.config/carapace/specs/mycli.yaml
```

A `CommandRunner` without subcommands accepts the hidden option
`--completion <shell>` instead. `mycli completion --help` shows the
installation instructions.

The scripts contain no commands or options. On each TAB, the shell runs
`mycli __complete <words...> <word-being-completed>` and the runner answers
with the alternatives, so the installed script keeps working when the CLI is
updated. The request and response format is that of Cobra's `__complete`
command (one `value<TAB>description` line per alternative, then a `:<N>`
directive line), which is why Carapace can bridge to it.

The completion output must be the only output on stdout. To guarantee this
without any effort from the program, the process exits with exit code 0 as
soon as a completion response or script has been written, so that nothing the
program does after `CommandRunner.runner()` returns (such as printing the
result) can corrupt it. See `CompletionSettings.exitAfterResponse` below to
turn that off.

### What gets completed

- Subcommand names (not hidden ones), with the first line of their description.
- Option names: `--name`, `--no-name` for negatable flags, and `-x`
  abbreviations, excluding hidden options and non-repeatable options already
  given on the command line. Subcommands spelled like options
  (e.g. `--version`) are included.
- Option values and positional arguments, depending on the option type:
  - `EnumOption`: the enum values.
  - Options with `allowedValues` (or `allowedHelp`): those values, with the
    help text as description.
  - `MultiOption`: the allowed element values, keeping the elements already
    typed before the separator (`a,b<TAB>` offers `a,b,c`).
  - `DirOption`: the shell's own directory completion.
  - `FileOption`, and any other option type without known values
    (e.g. `StringOption`, `IntOption`): the shell's own file completion.
  - `FlagOption`: nothing.
- `--option=value` is completed as well.
- Mutually exclusive option groups: once an option of a `MutuallyExclusive`
  group is given (by name or as a positional argument), the other options of
  the group are no longer offered, and a positional argument belonging to the
  group is not completed.

Completion works on partial command lines, so missing mandatory options or
subcommands never block it. The same goes for the built-in `help` command:
`mycli help deploy` shows the usage of `deploy` even though its mandatory
options are not given, just like `mycli deploy --help` does.

### Custom completion for an option type

Override `complete` on an option type to offer your own alternatives,
synchronously or asynchronously:

```dart
class ServerOption extends StringOption {
  const ServerOption({super.argName, super.helpText});

  @override
  Future<CompletionResult> complete(final CompletionContext context) async {
    final servers = await fetchServerNames();
    return CompletionResult.values([
      for (final server in servers)
        CompletionCandidate(server.name, description: server.region),
    ]);
  }
}
```

`CompletionContext` provides the word being completed, the preceding words,
the commands on the command line, and the raw (unvalidated) string values of
the options already typed, via `context.parsedArgs`. Option values are not
resolved from environment variables, configuration files or the configuration
broker, so that completion is fast and never fails. The shell's environment
variables are available as `context.environment` for custom completions that
need them (e.g. a server URL to fetch the alternatives from).

Besides `CompletionResult.values(...)` and `.strings(...)`, the result can be
`CompletionResult.files(extensions: ['yaml', 'yml'])`, `.directories()` or
`.none()`. The candidates are offered as returned; the shell filters them by
the typed prefix.

### Settings

```dart
CommandRunner(
  'mycli',
  'My CLI',
  // Disable all completion support:
  completion: CompletionSettings.disabled,
  // Or keep it but leave the completion command out of the usage help:
  // completion: CompletionSettings(hideCommand: true),
  // Or return from runner() after completion output instead of exiting
  // the process, e.g. when running the runner in-process in tests:
  // completion: CompletionSettings(exitAfterResponse: false),
);
```

A CLI that defines its own `completion` subcommand or `--completion` option
takes precedence over the built-in ones.
