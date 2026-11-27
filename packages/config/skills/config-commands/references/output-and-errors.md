# Usage text, output, and usage errors

- [The usage text of a command](#the-usage-text-of-a-command)
- [Where output goes](#where-output-goes)
- [Usage errors that the application throws](#usage-errors-that-the-application-throws)
- [A custom layout of usage errors](#a-custom-layout-of-usage-errors)
- [Settings for usage errors](#settings-for-usage-errors)

## The usage text of a command

The framework generates the usage from the definitions. These parameters of `CommandImpl`, and of its `branch` and `leafWithRunFunction` constructors, shape it:

| Parameter | Effect |
|---|---|
| `description` | The text at the top of the usage of the command. Its first line is the summary in the command list of the parent. |
| `summary` | Replaces that first line in the command list. |
| `options`, `persistentOptions` | The synopsis line, such as `Usage: mytool greet <name> [--times=<integer>]`, and the option list. |
| `invocation` | Replaces the generated synopsis of the command. Use it only when the generated line does not describe the command. |
| `usageFooter` | A text at the end of the usage. On the runner the parameter is `rootFooter`. |
| `category` | Commands with the same category are listed under that heading in the usage of the parent. |
| `aliases` | Other names that run the command. |
| `hidden: true` | The command runs but is not listed. |

The option list of a subcommand has `-h, --help` and the options of the command. The other persistent options of its parents are valid but not listed. A command that lists some of them overrides `inheritedUsageOptions`:

```dart
@override
List<OptionDefinition> get inheritedUsageOptions => [
  ...super.inheritedUsageOptions, // --help
  GlobalOption.verbose,
];
```

A listed option that has a `group` appears under the headline of that group, together with the options of the command in the same group.

`UsageSettings(usageLineLength: 80)` in the `UsageOutputHandler` of the runner wraps the usage text at that width.

## Where output goes

```dart
usageOutput: UsageOutputHandler(
  sinks: OutputSinks(out: out, err: err),
),
```

- `out` receives the usage text of `--help` and `help`. The default is stdout.
- `err` receives the usage errors. The default is stderr.
- Completion output has its own sinks: `completion: CompletionSettings(sinks: OutputSinks(out: out))`.

The output of the commands themselves is the business of the application. A sink or a logger that the commands fetch from `context.provider` keeps it testable.

## Usage errors that the application throws

A command or a middleware reports a mistake of the user that only it can detect by throwing a usage exception. The exception passes the `onError` hooks of the middlewares. Then the framework prints it to the `err` sink, and `run` throws it.

| Thrown | What is printed after the message |
|---|---|
| `CommandUsageException(message, command)` | The usage of `command`. |
| A `UsageException` that is not a `CommandUsageException` | The `usage` text of the exception, then the usage of the runner. |

Throw the first one, so that the user sees the usage of the command that the error is about:

| Thrown in | Command to pass |
|---|---|
| A command | `this` |
| A middleware | `context.leaf().command` |
| An action option | `context.command` |
| A helper function | The helper takes the command, or the context, as a parameter. |

An exception class of the application for usage errors extends `CommandUsageException`:

```dart
class AppUsageException extends CommandUsageException {
  AppUsageException(super.message, super.command, {this.hint});

  final String? hint;
}
```

## A custom layout of usage errors

The standard printer writes the `message` of the exception, an empty line, and the usage. To print more, extend it:

```dart
class AppUsageExceptionPrinter extends StandardUsageExceptionPrinter {
  const AppUsageExceptionPrinter();

  @override
  void printException(
    UsageException exception, {
    required UsageOutputHandler usageOutput,
    CommandDefinition? fromCommand,
  }) {
    super.printException(
      exception,
      usageOutput: usageOutput,
      fromCommand: fromCommand,
    );
    if (exception is AppUsageException) {
      if (exception.hint case final String hint) {
        usageOutput.sinks.err.writeln('\n$hint');
      }
    }
  }
}
```

The runner gets the printer in the exception settings of its usage output:

```dart
usageOutput: UsageOutputHandler(
  exceptionSettings: UsageExceptionSettings(
    exceptionPrinter: const AppUsageExceptionPrinter(),
  ),
),
```

- The printer serves every usage error of the runner, also those of the framework.
- It writes to `usageOutput.sinks.err` only, so the output follows the sinks of the runner.
- For a layout that does not start with the standard output, the printer implements `UsageExceptionPrinter` and writes everything.

## Settings for usage errors

| Need | Setting |
|---|---|
| `run` returns null after a usage error, and does not throw | `UsageExceptionSettings(noUsageException: true)` |
| The framework prints nothing, and the caller of `run` prints the exception | `UsageExceptionSettings(noUsageExceptionOutput: true)` |
| Code that sees every usage error, such as a counter of invalid command lines | `UsageOutputHandler(addExceptionHandlers: [UsageExceptions.simpleHandler((exception, usageOutput, fromCommand) { ... })])` |

No middleware runs for a usage error of the command line, so an exception handler is the place for code that must see those.
