# CLI behavior: baseline, reach, and forced changes

## Baseline invocations

Run the CLI the way its users do. Turn analytics off, and use a state that needs no credentials. Skip an invocation that would call a remote service or change stored state, and note it.

Capture stdout, stderr, and the exit code of each:

| Invocation | Shows |
|---|---|
| No arguments | Root usage |
| `--help` | Root usage, global options |
| `<path> --help` for every command path, hidden commands included | Usage of each command |
| `help <path>` for a leaf, a branch, and a hidden command | The help command |
| Each option-style command (group C of the inventory): alone, before a subcommand, after a subcommand | What becomes an action option |
| An unknown command. An unknown option on a command. | Parse errors |
| A command without one of its mandatory options. An invalid option value. | Configuration errors |
| A global option before the command, and the same option after the command | Placement of global options |
| Each colliding spelling (step 2), before and after its subcommand | Shadowing |
| A command that fails while it runs, if one can fail offline | Error mapping, exit code |
| The completion command and its subcommands with `--help`, if the CLI has one | Completion |

## Which invocations reach which hook

Before the migration:

| Invocation | Runner: `determineAnalyticsSettings`, `setLogLevel`, `onBeforeRunCommand`, a `runCommand` override | Wrapper in the base command |
|---|---|---|
| A project command on a valid command line | Yes | Yes |
| `--help`, `-h`, `help <command>`, no arguments | Yes | No |
| An option-style command that a `runCommand` override handles | The code before that check | No |
| An unknown command or subcommand, or a missing subcommand | Yes | No |
| An unknown option, or an option without its value, anywhere on the line | No | No |
| An invalid value of a global option | `determineAnalyticsSettings` only | No |
| A missing mandatory option, or an invalid option value, of the command | Yes | The part that ran before the options were resolved, if any |

After the migration:

| Invocation | Root middlewares | Middlewares of a command | Command `run` |
|---|---|---|---|
| A project command on a valid command line | Yes | Yes, for each command on the line | The last command only |
| `--help`, `-h`, anywhere on the line | Yes | No | No |
| `help <command>` | Yes. `context.leaf().command` is a built-in help command, not `<command>`. | No | No |
| No arguments | Yes. `context.leaf().command` is the runner. | | No. The root usage is printed. |
| A global action option | Yes | No | No |
| An action option of a command | Yes | From the root through the command that defines it | No |
| Any usage error: unknown command or option, missing or invalid value, missing subcommand | No | No | No |
| The built-in `completion` command | Yes | | Built-in |
| A completion request for an option value | Yes. `runMode` is `completion`. | Yes | No |
| A completion request for a command or option name | No | No | No |

The two differences that matter most:

- Root middlewares now run in cases where no project command runs. Code that moved from the base command needs a guard. See [patterns.md](patterns.md#reach-and-guards).
- All usage errors are now raised before the first middleware. Code that ran before an unknown command, a missing subcommand, or a usage error of a command, such as an update check or a consent prompt, no longer runs in that case. This is forced.

## Forced changes

Accept these, update the tests and user docs, and list them in the report.

Usage text:

- The usage line of the root is `Usage: <executable> [global-options] <command> [arguments]`.
- The usage line of a command lists its options, for example `Usage: <executable> greet --name=<name> [--region=<region>]`. It was `Usage: <executable> greet [arguments]`.
- The option list of a command has a new layout, and no `-h, --help` row.
- The root usage lists the built-in `completion` command.

Usage errors:

- The messages have new wording and name the command, for example:
  - `<executable>: Unknown subcommand: "x"`
  - `<command>: Unknown option: --x.`
  - `<command>: Option "--x" is mandatory.`
  - `<command>: Missing value for option: --x.`
  - `<command>: A subcommand is required under <command>.`
- The framework prints the message and the usage of the command to `usageOutput.sinks.err`, then throws.
- All errors of the command line are found before anything runs, and are reported together.
- The framework handles a `UsageException` that a command or a middleware throws in the same way. What it prints depends on the type of the exception. See [patterns.md](patterns.md#usage-errors-thrown-during-execution).

Command line:

- `--help` after a command with missing mandatory options prints the usage, as before. `help <command>` does the same.
- `help <command>` does not find a hidden command. `<command> --help` does.
- An action option runs wherever it is valid on the line, also next to a subcommand.

Analytics, with `BetterCommandRunner`:

- No event is sent for a usage error: neither `invalid` nor the event of the command.
- The event of a global action option has the name of the option, such as `--version`.
- The event of `--help` is `help`, also after a command, where it was the name of the command. The event of `help <command>` is `help`, as before.
- The event of a run with no arguments has the name of the executable. It was `help`.
- `determineAnalyticsSettings` is also called for a completion request for an option value.

Completion:

- Completion is enabled. A CLI that had no completion command has the built-in one now.
- The `completion` subcommands for generating and embedding scripts are gone. `completion` prints the script for a shell, and `completion install` installs it.
- Installed scripts of the old kind keep their old content. Users install again once.
