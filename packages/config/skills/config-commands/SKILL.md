---
name: config-commands
description: Builds command-line applications with the command framework of the Dart `config` package, `package:config/command.dart`, with its `CommandRunner`, commands and subcommands, `CommandContext`, middlewares, action options such as `--version`, usage errors, and shell completion. Use when creating or changing a CLI, a command, or a middleware that is built on `CommandRunner` or `Command`, or on `BetterCommandRunner` or `BetterCommand` of `cli_tools`.
---

# Command-line applications with the `config` command framework

A `CommandRunner` is the root of a tree of commands. Every command has typed options and middlewares. The tree is defined once. Each call to `run` resolves one command line into a chain of `CommandContext` objects and runs the last command on the line, inside the middlewares of the commands before it. Help, usage errors, and shell completion are built in.

```dart
import 'package:config/command.dart';
import 'package:config/config.dart';
```

Options are defined and read as the skill `config-options` describes. `BetterCommandRunner` and `BetterCommand` of `cli_tools` extend `CommandRunner` and `BridgeCommand`, so this skill applies to them.

## References

- [middlewares.md](references/middlewares.md): the forms of a middleware, their order, which command lines reach them, the objects they share with commands, and error mapping.
- [output-and-errors.md](references/output-and-errors.md): the usage text of a command, where output goes, usage errors that a command throws, and a custom layout of errors.
- [testing.md](references/testing.md): tests of commands, middlewares, usage errors, and completion.
- [single-command.md](references/single-command.md): a program without subcommands.

The package source is the authority on signatures. After `dart pub get`, take the `config` package root from `.dart_tool/package_config.json` and read:

- `README_command.md`: persistent options, action options, incomplete command lines, arguments after `--`, pass-through commands, and shell completion.
- `lib/src/command/command_runner.dart`: the class doc of `CommandRunner`, with the phases of a run.
- `example/command_example.dart`: a complete program.

## A complete program

```dart
enum GlobalOption<V extends Object> implements OptionDefinition<V> {
  verbose(
    FlagOption(
      argName: 'verbose',
      argAbbrev: 'v',
      negatable: false,
      defaultsTo: false,
      helpText: 'Print more.',
    ),
  );

  const GlobalOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

enum GreetOption<V extends Object> implements OptionDefinition<V> {
  name(
    StringOption(
      argName: 'name',
      argPos: 0,
      mandatory: true,
      helpText: 'Who to greet.',
    ),
  ),
  times(
    IntOption(argName: 'times', defaultsTo: 1, min: 1, helpText: 'How often.'),
  );

  const GreetOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

/// What the commands write to. A middleware creates one for each run.
class Output {
  Output(this.sink, {required this.verbose});

  final StringSink sink;
  final bool verbose;
}

class GreetCommand extends CommandImpl<GreetOption, int> {
  GreetCommand()
    : super(
        name: 'greet',
        description: 'Greets someone.',
        options: GreetOption.values,
      );

  @override
  int run(CommandContext<GreetOption, int> context) {
    final name = context.config.value(GreetOption.name);
    final times = context.config.value(GreetOption.times);
    final output = context.provider.fetch<Output>();
    for (var i = 0; i < times; i++) {
      output.sink.writeln('Hello $name');
    }
    if (output.verbose) output.sink.writeln('Greeted $times time(s).');
    return 0;
  }
}

/// Builds the command tree. The entry point and the tests both call this.
/// The sinks default to stdout and stderr.
CommandRunner<GlobalOption, int> buildRunner({
  StringSink? out,
  StringSink? err,
}) {
  final sinks = OutputSinks(out: out, err: err);
  return CommandRunner<GlobalOption, int>(
    'mytool',
    'An example tool.',
    globalOptions: GlobalOption.values,
    subcommands: [GreetCommand()],
    usageOutput: UsageOutputHandler(sinks: sinks),
    completion: CompletionSettings(sinks: sinks),
    middlewares: [
      Middlewares.onBeforeRun((context) {
        final verbose = context.config.value(GlobalOption.verbose);
        context.provider.store(Output(sinks.out, verbose: verbose));
      }),
    ],
  );
}

Future<void> main(List<String> args) async {
  try {
    exitCode = await buildRunner().run(args) ?? 0;
  } on UsageException {
    // The framework has already printed the error and the command's usage.
    exitCode = 1;
  }
}
```

`mytool greet World --times 2 -v`, `mytool -v greet World`, `mytool greet --help`, `mytool help greet`, and `mytool completion install` all work.

## Where each piece goes

| Piece | Place |
|---|---|
| An option of one command | `options:` of that command. Valid after the name of the command. May be positional. |
| An option of a branch of commands | `persistentOptions:` of the branch command. Valid anywhere after that command. Named only. |
| An option of the whole program | `globalOptions:` of the runner. Valid anywhere on the line. Named only. |
| The work of a command | Its `run`. |
| Logic for several commands: setup and teardown, checks, error mapping | A middleware on the command that those commands share as an ancestor. |
| An object that commands share during a run, such as a logger or a client | `context.provider`. A middleware stores it, or the caller of `run` passes a provider. |
| An argument that is written as an option and runs like a command, such as `--version` | An [action option](#action-options). |

The runner, the commands, and the options hold definitions only: names, descriptions, options, subcommands, middlewares, and output settings. Everything that belongs to one run is on the `CommandContext`. One runner then serves any number of runs, which the tests rely on.

## Rules for the tree

- **Type arguments.** `O` is the option enum of the command, and `OptionDefinition` for a command without options. `T` is the result type, the same for the runner and every command. Write both on every `CommandRunner`, `CommandImpl.leafWithRunFunction`, and `CommandImpl.branch`, as in `CommandRunner<GlobalOption, int>(...)`. Inferred type arguments can fail with a `TypeError` when the program runs.
- **Result.** `int` as `T` carries the exit code. `run` returns `T?`, and it returns null after `--help`, a usage text, and a completion response.
- **One function builds the tree.** A command object belongs to one parent. The builder function creates the runner and all its commands, and it takes what differs between production and tests as parameters.
- **Branch commands.** A command with subcommands does not run on its own. A command line that ends at it is a usage error, or prints the usage of the command when the command has `canRunAsLeafCommand: true`.
- **Global options.** A mandatory global option is required on every command line, also for the built-in `completion` command. Give a global option a default, or leave it optional and check it where the value is needed.
- **Built-in names.** The option `--help` with `-h`, and the commands `help` and `completion`, are built in. A global option with the name `help` or the abbreviation `h` is a definition error.

| Command form | Use |
|---|---|
| `class GreetCommand extends CommandImpl<GreetOption, int>` | The standard form. Name, description, and options go to the `super` constructor. |
| `CommandImpl.leafWithRunFunction<O, T>(name:, description:, options:, run:)` | A small command without a class. |
| `CommandImpl.branch<O, T>(name:, description:, persistentOptions:, subcommands:, middlewares:)` | A command that groups subcommands. |
| `class GreetCommand extends BridgeCommand<GreetOption, int>` | Code that comes from `package:args`. Name, description, and aliases are getters. |

## Read values

```dart
final name = context.config.value(GreetOption.name);
final verbose = context.root().config.value(GlobalOption.verbose);
final url = context.prev!.config.value(DbOption.url);
final output = context.provider.fetch<Output>();
```

- `context.config` holds the options of the command itself.
- `context.root().config` holds the global options.
- `context.prev` is the context of the command before this one on the line, where the persistent options of that command are.
- `context.provider` holds the shared objects, keyed by type.

When several commands read the same values, an extension on `CommandContext` gives them getters. See [middlewares.md](references/middlewares.md#objects-of-one-run).

## Middlewares

A middleware of a command wraps everything after that command on the line: the middlewares of the later commands, and the `run` of the last one. A middleware of the runner wraps every run.

```dart
final db = CommandImpl.branch<DbOption, int>(
  name: 'db',
  description: 'Database commands.',
  persistentOptions: DbOption.values,
  subcommands: [MigrateCommand()],
  middlewares: [
    Middlewares.withHooks(
      onRun: (context) {
        if (context.config.errors.isEmpty) {
          final url = context.config.value(DbOption.url);
          context.provider.store(Database(url));
        }
        return context;
      },
      onFinally: (context) =>
          context.provider.maybeFetch<Database>()?.close(),
    ),
  ],
);
```

The middlewares of the runner also run when no command of the application runs: for `--help`, `help <command>`, an action option, the built-in `completion` command, and a completion request for an option value. Those of a branch command run for some of these. Two rules follow:

- **Incomplete command lines.** For help, action options, and completion, a mandatory option may be missing, such as `--url` of `db` above. Reading an option that has an error throws an `InvalidParseStateError`. A middleware that reads a mandatory option checks `context.config.errors.isEmpty` first.
- **Work that is meant for a command.** A check, a prompt, an output, or a network call that belongs to the run of a command needs a guard.

[middlewares.md](references/middlewares.md) has the guards, the other forms, and the order.

## Action options

```dart
class VersionOption extends FlagOption with ActionOptionMixin<bool> {
  const VersionOption()
    : super(
        argName: 'version',
        negatable: false,
        helpText: 'Print the version.',
      );

  @override
  FutureOr<R?> run<O extends OptionDefinition, R>(
    CommandContext<O, R> context,
  ) {
    stdout.writeln('mytool 1.2.3');
    return null;
  }
}
```

It is a value of the option enum of the command where it is valid: `version(VersionOption())` in `GlobalOption` makes it valid on the runner and after every command.

- **Runs instead of a subcommand**, also on a command line that is otherwise incomplete. The middlewares run from the root through the command that defines the option, and `context` is the context of that command.
- **Takes the place of a subcommand.** A subcommand or another action option after it is a usage error: `mytool --version greet` fails, `mytool greet --version` runs. Regular options may follow it.
- **`isExclusive`.** An action option that overrides it to return false may be written anywhere on the line, like the built-in `--help`.
- **`--help` wins.** `mytool --version --help` prints the usage, in either order.

## Errors and exit codes

| Error | What happens | Response |
|---|---|---|
| A mistake in the definitions: `OptionDefinitionError`, `CommandDefinitionError` | Every `run` checks the whole tree first and throws. | Fix the definition. |
| A mistake on the command line, or in the environment or the configuration file | The framework prints all errors of the line and the usage of the command, then `run` throws a `UsageException`. No middleware has run. | The entry point sets the exit code. |
| A usage error that a command finds while it runs | The command throws `CommandUsageException('message', this)`. The framework prints it like the errors above. | The same. |
| Any other failure | It passes the `onError` hooks of the middlewares and then leaves `run`. | An `onError` middleware on the runner maps it to a message and an exit code. See [middlewares.md](references/middlewares.md#error-mapping). |

## Shell completion

Completion is built in for Bash, Zsh, Fish, PowerShell, and Carapace. Users run `mytool completion install` once.

- **Stdout.** During a completion request, stdout carries the response. A middleware writes nothing then: it tests `context.runMode == CommandRunMode.completion`. An entry point that prints after `run` returns sets `completion: CompletionSettings(exitAfterResponse: true)` on the runner.
- **Option values.** The alternatives of a value come from the option type. For other alternatives, the option overrides `complete`: skill `config-options`, `references/custom-option-types.md`.

Everything else is in the section "Shell completion" of `README_command.md`.

## Other topics

| Topic | Read |
|---|---|
| The placement of persistent options, and two commands that use one option name | `README_command.md`, "Persistent options" |
| A command that runs on an incomplete command line | `README_command.md`, "Commands / actions accepting incomplete command lines" |
| Extra arguments after the options, and `--` | `README_command.md`, "Parser settings and extra positional arguments" |
| A command that forwards its arguments to another program | `README_command.md`, "Pass-through commands" |
| Option values from a configuration file | Skill `config-options`, `references/configuration-files.md` |

## Done when

- `dart analyze` reports nothing.
- `--help` on the runner prints the usage. A definition error shows only when the runner runs, so run it once after every change of the tree or the options.
- The tests cover the new command or middleware. See [testing.md](references/testing.md).
