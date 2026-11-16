# New Dart CLI authoring framework

The new `CommandRunner` builds a command-line application from a tree of
commands, typed options, and middlewares. It resolves each
command's configuration from the command line, environment variables, and
configuration files, then runs the last command. Middlewares on a command wraps
the commands below it.

The command tree, options, and middleware are defined when the runner is created.
Mistakes in those definitions are fail-fast. A mistake in the user's input is
reported as a usage error. Help and shell completion are built in.

## Design

Uses the concept of middlewares to customize the execution logic
of the command tree. The legacy CommandRunner relied on method overrides
to customize the execution logic. This middleware approach allows for
cleaner composition.

Separates static configuration from dynamic execution. The command tree,
options, middlewares, settings for usage output and error handling are
configured statically. Execution performs configuration resolution and
command execution and these do not mutate the CommandRunner, Command, or
Option instances. This provides separation of concerns and makes the command
code reentrant, which also makes it easier to write tests.

## Persistent options

A persistent option belongs to the command that defines it and may be written
anywhere after that command on the command line, including after its subcommands.
The value is recorded on the defining command's context where it can be read by
that command as well as its successor commands.

Global options are the root command's persistent options, so they are valid
anywhere on the command line:

```sh
executable --verbose subcommand
executable subcommand --verbose
executable subcommand nested --verbose
```

A persistent option of a branch command starts at that command:

```sh
executable build --profile ci check
executable build check --profile ci
```

Both set `build`'s `--profile`. A command's own (non-persistent) options are
valid on that command, before the next subcommand. 

> Persistent options are always named; a positional option cannot be persistent,
 since it would conflict with additional subcommands.

## Action options

An action option behaves similarly to a subcommand. It has a run method and the
runner runs it instead of a subcommand.

### Example: --version action option

`--version` is often supported by CLI commands and typically perform no work
besides printing the version information.

```sh
executable --version
executable --version subcommand  # prints the version, subcommand is not run
executable subcommand --version  # the same, when --version is a global option
```

The rest of the command line is still parsed, so an unknown subcommand or
option is an error.

### Built-in action options

`--completion <shell>` is automatically defined in on a runner with no
subcommands. A runner with subcommands has the `completion` subcommand instead.
Both print the completion script for a shell. The subcommand can also install
it, see [Shell completion](#shell-completion).

### Help

`--help` / `-h` is an action option and also a persistent option, so it may come
before or after other subcommands. It prints the usage of the last command on
the line.

```sh
executable --help
executable --help subcommand
executable subcommand --help
```

## Commands / actions accepting incomplete command lines

A command runs when its command line is complete: mandatory options are set, a
mandatory exclusive group has a choice, and a command that requires a
subcommand has one.

A command or action option that sets `acceptsPartialCommandLine` can runs on
an incomplete line. Action options do this by default; commands do not. This
effectively means that the runner reports what was written on the command line
and ignores any errors due to what was left out:

- Ignored: a mandatory option never written, a mandatory exclusive group with
  no member chosen, and a required subcommand never named.
- Reported: unknown options and subcommands, invalid values, options that
  exclude each other, and a missing value for an option that was written
  (`--target` with nothing after it).

The ignored errors stay on `CommandContext.config.errors`.

```sh
executable deploy --help            # prints usage, even without mandatory options
executable help deploy              # prints usage, via the help command
executable deploy --bogus --help    # error: unknown option
executable deploy --help --target   # error: missing value for --target
```

The built-ins `--help`, the `help` command, and `--completion` accept an
incomplete line.
A custom command opts in by overriding `acceptsPartialCommandLine`.

## Shell completion

The `CommandRunner` in `package:config/command.dart` has built-in command line
completion for Bash, Zsh, Fish, PowerShell and the
[Carapace](https://carapace.sh) completion framework. It is enabled by default
and requires no work from the CLI developer.

End users install the completion once. A `CommandRunner` with subcommands gets
a `completion` subcommand, whose `install` subcommand installs the completion
for the current user:

```sh
mycli completion install             # for the shell it is run from
mycli completion install --dry-run   # only print what it would do
mycli completion install --shell zsh # for a given shell
```

It prints each change it makes. The script is saved where the shell looks for
it, and for the shells that need it, lines that load the script are appended
to the shell's startup file:

| Shell      | Script                                                     | Startup file                            |
|------------|------------------------------------------------------------|-----------------------------------------|
| Bash       | `~/.local/share/bash-completion/completions/mycli`         | `~/.bashrc` (macOS: `~/.bash_profile`)  |
| Zsh        | `~/.local/share/zsh/site-functions/_mycli`                 | `~/.zshrc`                              |
| Fish       | `~/.config/fish/completions/mycli.fish`                    |                                         |
| PowerShell | `Completions/mycli.ps1` next to the profile                | `$PROFILE`                              |
| Carapace   | `carapace/specs/mycli.yaml` in the user config directory   |                                         |

`XDG_DATA_HOME`, `XDG_CONFIG_HOME`, `BASH_COMPLETION_USER_DIR` and `ZDOTDIR`
are honored. Installing again overwrites the script and leaves a startup file
that already loads it as it is. In Zsh, the added lines also initialize the
completion system (`compinit`) if the startup file has not done so.

Without a subcommand, `completion` prints the script instead, for a manual
installation:

```sh
# Bash: add to ~/.bashrc
source <(mycli completion --shell bash)
# Zsh: add to ~/.zshrc after compinit, or save as _mycli in a directory on $fpath
source <(mycli completion --shell zsh)
# Fish
mycli completion --shell fish > ~/.config/fish/completions/mycli.fish
# PowerShell: add to $PROFILE
mycli completion --shell powershell | Out-String | Invoke-Expression
# Carapace: save to the specs directory shown by `carapace --help`
mycli completion --shell carapace > ~/.config/carapace/specs/mycli.yaml
```

`--shell` and `--command` are persistent options of `completion`, so they may
be written before or after `install`. When `--shell` is not given, the shell
is detected (`detectCompletionShell`): it is the nearest ancestor process that
is a shell the user types in, so a wrapper script of the CLI does not hide the
shell it was started from. Failing that it is the login shell (`$SHELL`), or
PowerShell on Windows. If no supported shell is found, a usage error asks for
`--shell`. Carapace is not a shell and is always given explicitly.

A `CommandRunner` without subcommands has the built-in global option
`--completion <shell>` instead (listed under "Global options" next to
`--help`), which prints the same script:

```sh
source <(mycli --completion bash)
```

Like `--help`, `--completion` acts on the command line as given: when present,
the script is printed and nothing else runs, even if the command line is
otherwise incomplete. The installation instructions for a shell are in the
comment header of its script; `mycli completion --help` lists them for all
shells.

For a wrapper script of the CLI (same commands and options under another
name), install or generate the script with `--command <name>`:
`mycli completion install --command mywrap`, or
`source <(mycli completion --shell bash --command mywrap)`. The script then
completes `mywrap`, while sending the completion requests to `mycli` directly,
so that nothing the wrapper prints or adds to the arguments can interfere.
Programs without subcommands can do the same via the API,
`CompletionShell.bash.script('mycli', commandName: 'mywrap', viaOption: true)`.

The scripts contain no commands or options. On each TAB, the shell runs
`mycli __complete <words...> <word-being-completed>` and the runner answers
with the alternatives, so the installed script keeps working when the CLI is
updated. The request and response format is that of Cobra's `__complete`
command (one `value<TAB>description` line per alternative, then a `:<N>`
directive line), which is why Carapace can bridge to it.

The completion output must be the only output on stdout. After a completion
response or script has been written, `CommandRunner.run()` returns null, and
anything the program then prints (such as the result) would corrupt it. A
program that does so should set `CompletionSettings.exitAfterResponse`, see
below: the process then exits with exit code 0 as soon as the completion
output has been written.

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
the options already typed, via `context.parsedArgs`. The shell's environment
variables are available as `context.environment` for custom completions that
need them (e.g. a server URL to fetch the alternatives from).

When the `CommandRunner` completes an option value, it also resolves the
configurations of the commands typed so far, from the arguments, environment
variables, configuration files and the configuration broker, like when the
command line is run. Since the command line is not finished, errors such as
missing mandatory options are not reported. They stay on
`CommandContext.config.errors`. `commandContextOf(context)` returns the
resolved context of the last command, and its `prev` contexts are those of
the preceding commands:

```dart
@override
CompletionResult complete(final CompletionContext context) {
  final leaf = commandContextOf<OptionDefinition, int>(context);
  final project = leaf?.config.optionalValue(projectOption);
  return CompletionResult.strings(resourceNames(project));
}
```

The middleware of those commands runs as well, around the `complete` call,
so that it can prepare what `complete` needs, e.g. store a service on
`CommandContext.provider`. No command `run` method is called. A middleware
tells the two apart with `CommandContext.isCompletion`, and should skip
anything meant only for a command being run, such as analytics or printing:
output on stdout would end up among the completion alternatives.

Subcommand and option name completion neither resolves configurations nor
runs middleware. Completion should be fast and should not throw. If resolving
the configurations, a middleware or `complete` throws, nothing is offered.

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
  // Or exit the process right after completion output, instead of returning
  // from run(): completion: CompletionSettings(exitAfterResponse: true),
);
```

A CLI that defines its own `completion` subcommand takes precedence over the
built-in one. That subcommand can be a `CompletionCommand` with its own
`CompletionInstaller`:

```dart
CompletionCommand<int>(
  installer: CompletionInstaller(environment: {'HOME': sandboxHome}),
)
```

The options of the built-in command, `--shell` and `--command`
(`CompletionOption`) and `--dry-run` (`CompletionInstallOption`),
must not be the names of global options of the application.

The built-in global options `--help` and `--completion`
(`BuiltinGlobalOption`) are kept apart from the application's typed
`globalOptions`, so they are available for any option type without being
listed; the application's global options must not share their names or
abbreviations.
