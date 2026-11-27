# Target patterns

`AppCommand`, `AppLogger`, `AppUsageException`, `ApiClient`, and `GlobalOption` stand for the project's own types. The result type of the runner is `int` in the examples.

- [Per-run data](#per-run-data)
- [Middlewares](#middlewares): one responsibility, forms, order, reach and guards, base command, runner overrides, usage errors, where output goes
- [Action options](#action-options)
- [Entry point](#entry-point)
- [Tests](#tests)

## Per-run data

### Where an object lives

Option values stay on the context. `context.config` holds the options of the command itself. `context.root().config` holds the global options. The contexts of the commands before it are on `prev`.

| When the object exists | Who reads it | Where it lives |
|---|---|---|
| Before `run` (the runner constructor, or the caller before `run`) | The runner, or one callback fixed at construction (`setLogLevel`, the usage sinks) | A final field of the runner, or the caller. |
| Before `run` | Commands or middlewares | A final field of the runner works. `context.provider` is the convenient place, so commands reach it without the runner. The caller passes `provider:` to `run`, or a middleware stores the field at the start of the run. |
| During `run`, in one command | That command only | A local variable in its `run`. |
| During `run`, in one command | Other code too, such as a helper or a teardown middleware | The command creates it where its work produces it, and stores it on `context.provider`. A middleware that reads it uses `maybeFetch`, because the command may not have run. |
| During `run` | More than one command | A middleware creates it, stores it on `context.provider`, and releases it in `onFinally` of the same middleware. |

An object is created where it belongs, and it travels on the context. A constructor parameter or a field is for an object that exists before `run`.

`configBroker` runs during resolution, before every middleware. It reads a construction-time field of its command or runner. The broker of a subcommand also reads what the caller seeded on the provider, through `prevContext`. The broker of the runner gets a null `prevContext` and no provider, so what it needs is a construction-time field of the runner.

An option completer reads a value stored by a middleware that also runs for completion requests, or a value the caller seeded. No output and no prompt in completion mode.

The usage output (`UsageOutputHandler`), the completion output (`CompletionSettings`), and the `setLogLevel` callback are fixed at construction and get no context. A logger they use is one the caller owns. The runner builder receives sink adapters for that logger (`OutputSinks`) and the `setLogLevel` callback.

The provider is keyed by the type argument. `store<AppLogger>(StdOutAppLogger())` is read with `fetch<AppLogger>()`. Give `store` the type argument whenever the value is a subtype or a fake. `fetch` throws `ContextValueNotFound`. Use `maybeFetch` where an empty slot is a valid state. Two values of one type would share a slot, which is usually not desired. A value derived during the run, such as a resolved project directory, gets its own class.

### How a reader reaches a stored value

When only one file reads the value, it can use a local function in that file:

```dart
AppLogger _loggerOf(CommandContext<OptionDefinition, int> context) =>
    context.provider.fetch<AppLogger>();
```

When commands in other files read it, an extension on `CommandContext` gives them a getter:

```dart
typedef GlobalConfiguration = Configuration<GlobalOption>;

extension AppContext<O extends OptionDefinition, T> on CommandContext<O, T> {
  GlobalConfiguration get globalConfiguration =>
      root().config as GlobalConfiguration;

  AppLogger get logger => provider.fetch<AppLogger>();

  ApiClient get apiClient => provider.fetch<ApiClient>();
}
```

The same choice for typed getters of global options: a function in the file, or an extension on `Configuration<GlobalOption>` when other files read them.

The client below depends on the resolved configuration, so the middleware creates it during the run and stores it for the commands:

```dart
BetterCommandRunner<GlobalOption, int> buildRunner({
  required ApiClient Function(GlobalConfiguration) createApiClient,
}) {
  return BetterCommandRunner<GlobalOption, int>(
    'app',
    'An example app.',
    globalOptions: GlobalOption.values,
    prependMiddlewares: [
      Middlewares.withHooks(
        onRun: (context) {
          context.provider.store<ApiClient>(createApiClient(context.config));
          return context;
        },
        onFinally: (context) => context.provider.fetch<ApiClient>().close(),
      ),
    ],
  );
}
```

The builder takes a factory for an object created from the resolved configuration. Tests pass a factory that returns a fake.

The `configBroker` of a subcommand sees the configurations of the commands before it, and what the caller seeded:

```dart
@override
ConfigurationBroker? configBroker(
  CommandContext<OptionDefinition, int>? prevContext,
) {
  if (prevContext == null) return null;
  return projectFileBroker(
    directory: prevContext.globalConfiguration.value(GlobalOption.projectDir),
    logger: prevContext.logger,
  );
}
```

## Middlewares

### One responsibility

Each middleware has one responsibility. A login check, an error mapping, and creating a client are three middlewares. The setup and teardown of one object are one responsibility and share one `withHooks`, so `onFinally` runs only when that setup ran.

### Forms

| Form | Use |
|---|---|
| `Middlewares.onBeforeRun((context) { ... })` | Runs before. Cannot replace the context. |
| `Middlewares.onRun((context) => context)` | Runs before. Returns the context to pass on, for example from `copyWith`. |
| `Middlewares.onReturn((context, result) => result)` | Runs after a normal return. Returns the result to pass back. |
| `Middlewares.onError((error, stackTrace, context) => ...)` | Runs after a throw. Returns a result to recover, or throws. |
| `Middlewares.onFinally((context) { ... })` | Runs last in both cases. Its own errors are ignored. |
| `Middlewares.withHooks(onRun:, onReturn:, onError:, onFinally:)` | The setup and teardown of one responsibility. |
| `class X extends CommandMiddlewareHooks<O, T>`, used as `const X().middleware` | A named unit with its own tests. Construction-time dependencies are constructor fields. State created during the run and read from more than one place goes on the provider. |
| `(next) => (context) async { ...; return next(context); }` | The raw form. Only this form can skip the rest of the run and return normally, by not calling `next`. |

### Order

On a `BetterCommandRunner`, the `onRun` hooks run in this order:

1. `prependMiddlewares`, in list order.
2. Built-in analytics: calls `determineAnalyticsSettings(context)`, stores `AnalyticsEnabled` on the provider, sends the command event.
3. Built-in log level: calls `setLogLevel`. Not for completion requests.
4. Middlewares added with `runner.addMiddleware` after construction, in call order.
5. The middlewares of each command on the command line, root to leaf.
6. The `run` of the last command, or of the action option.

The `onReturn`, `onError`, and `onFinally` hooks run in the reverse order.

Placement rules:

- A middleware that stores what `determineAnalyticsSettings` or `onAnalyticsEvent` reads goes in position 1.
- A middleware that reads `AnalyticsEnabled` goes in position 4.
- Logic for one branch of commands is added to that branch command with `addMiddleware`.
- An `onError` hook sees the errors of everything inside it: later middlewares and the command. It does not see errors of earlier middlewares or of its own `onRun`. Put error mapping outside everything whose errors it maps.

### Reach and guards

A root middleware runs for every valid command line, not only when a project command runs. It also runs for `--help`, `help <command>`, action options, the root usage, the built-in `completion` command, and completion requests for an option value. It does not run when the command line has a usage error. The full table is in [behavior-changes.md](behavior-changes.md#which-invocations-reach-which-hook).

Code that moved from a base command ran only when a project command ran. Give it that reach again. These functions live in the file that holds the middlewares. Move them to an extension on `CommandContext` when another file reads them too.

```dart
/// Whether an action option, such as `--help`, runs instead of a command.
bool runsActionOption<T>(CommandContext<OptionDefinition, T> context) {
  CommandContext<OptionDefinition, T>? current = context.root();
  while (current != null) {
    if (current.specifiedActionOptions().isNotEmpty) return true;
    current = current.next;
  }
  return false;
}

/// The project command that this run executes, or null when the run prints
/// help, runs an action option, or serves a completion request.
AppCommand? executedCommand<T>(CommandContext<OptionDefinition, T> context) {
  if (context.runMode == CommandRunMode.completion ||
      runsActionOption(context)) {
    return null;
  }
  return switch (context.leaf().command) {
    final AppCommand command => command,
    _ => null,
  };
}
```

`specifiedActionOptions()` covers one context, so the check walks the chain.

A completion request for an option value runs the middlewares with `context.runMode == CommandRunMode.completion`, the provider that was passed to `run`, and no command `run`. Stdout carries the completion response. Decide for each middleware:

- It stores something that a completer reads: it runs, without output and without a prompt.
- Anything else: it returns at once in completion mode.

### Base command

Each part of the old wrapper in the base command's `run` or `runWithConfig` has a destination:

| Part of the old wrapper | Becomes |
|---|---|
| `try`/`catch` that maps exceptions to messages and exit codes | `Middlewares.onError` on the runner |
| A check before the command (login, required mode) that depends on a property of the command | `Middlewares.onBeforeRun` on the runner, which reads the property from `executedCommand(context)` |
| A helper object built for the command, such as an output formatter | When more than one place reads it, a middleware stores it on the provider. A function in that file reads it, or an extension when other files read it |
| Cleanup after the command | `onFinally`, in the `withHooks` of its setup |
| The hook that subclasses implemented, such as `runWithOutput(config, output)` | Each leaf command overrides `run(context)` |

The base command keeps definitions only. A switch for one command, such as `requireLogin`, is a definition.

`run` is abstract in `Command`, so a branch command class needs one too. A branch command is never run: a command line that ends at it is a usage error. The base command has the one `run` that the branch commands share. It throws, as the `run` of `CommandImpl.branch` does.

```dart
abstract class AppCommand<O extends OptionDefinition>
    extends BetterCommand<O, int> {
  AppCommand({super.options});

  /// Whether the command needs a logged in user.
  bool get requireLogin => true;

  /// Runs this command. Leaf commands override this method.
  @override
  FutureOr<int?> run(CommandContext<O, int> context) =>
      throw UnsupportedError('Branch command $name should not be run.');
}

class GreetCommand extends AppCommand<GreetOption> {
  GreetCommand() : super(options: GreetOption.values);

  @override
  String get name => 'greet';

  @override
  String get description => 'Greets someone.';

  @override
  Future<int?> run(CommandContext<GreetOption, int> context) async {
    final name = context.config.value(GreetOption.name);
    context.logger.info('Hello $name, from ${context.apiClient.url}');
    return 0;
  }
}
```

The wrapper parts as middlewares, in the order the wrapper had:

```dart
runner.addMiddleware(
  Middlewares.onError((error, stackTrace, context) {
    if (error is UsageException || error is ExitException) {
      Error.throwWithStackTrace(error, stackTrace);
    }
    context.logger.error('${context.leaf().command.name} failed: $error');
    throw ExitException.error();
  }),
);

runner.addMiddleware(
  Middlewares.onBeforeRun((context) async {
    final command = executedCommand(context);
    if (command == null || !command.requireLogin) return;
    if (!await context.apiClient.isLoggedIn()) {
      context.logger.error('Log in first.');
      throw ExitException.error();
    }
  }),
);
```

The error mapping is added first, so it also maps the errors of the login check.

### Runner overrides and callbacks

| Old | Becomes |
|---|---|
| `runCommand` override: code before `super.runCommand` | `onBeforeRun` middleware |
| `runCommand` override: code after it, or in `finally` | `onReturn` or `onFinally` |
| `runCommand` override: `try`/`catch` around it | `onError` |
| `runCommand` override: test of an option, then an early return | An [action option](#action-options). For any other condition: the raw middleware form without a call to `next`. |
| `run` or `resolveConfiguration` override that stores the global configuration | Delete it. Read `context.globalConfiguration`. |
| `onBeforeRunCommand` | `onBeforeRun` middleware in position 4, which is where the callback ran. |
| `setLogLevel` | Stays a callback. It gets no context, so it suits a logger that the caller of `run` owns. A logger that a middleware creates gets its level in that middleware, from `context.config`. |
| `determineAnalyticsSettings()` | Stays an override; it is the extension point for consent. It takes the context, reads what position 1 middlewares stored, and returns false first when `context.runMode` is `CommandRunMode.completion`. |
| `sendAnalyticsEvent` override, `analyticsEnabled()` override | Move the logic into the `onAnalyticsEvent` callback and `determineAnalyticsSettings`. |
| `messageOutput` | `usageOutput` with `OutputSinks`. See [Where output goes](#where-output-goes). |

### Usage errors thrown during execution

A `UsageException` that a command or a middleware throws passes the `onError` hooks first. Then the runner handles it like a usage error of the command line: the usage exception handlers run, the printer writes to `usageOutput.sinks.err`, and `run` throws the exception.

An `onError` hook that maps errors rethrows a `UsageException` unchanged, as the error mapping above does.

The standard printer writes the `message` of the exception, an empty line, and then a usage text that depends on the type of the exception:

| Thrown | Usage text |
|---|---|
| `CommandUsageException(message, command)`, also the one from `usageException(message)` | The usage of `command`. |
| A `UsageException` that is not a `CommandUsageException` | The `usage` of the exception if it is not empty, then the root usage. |

#### Project subclasses of `UsageException`

A project class that extends `UsageException` changes to extend `CommandUsageException`. Then the user sees the usage of the command that the error is about, as with the usage errors of the framework.

```dart
class AppUsageException extends CommandUsageException {
  final String? hint;

  AppUsageException(super.message, super.command, {this.hint});
}
```

The constructor takes the command instead of a usage text. Each place that throws the exception passes it:

| Thrown in | Command to pass |
|---|---|
| A command | `this` |
| A middleware | `context.leaf().command` |
| An action option | `context.command` |
| A helper function | The helper gets the command, or the context, as a parameter. |

Throw a plain `UsageException` directly in the same way: as `CommandUsageException(message, command)`.

Keep `UsageException` as the superclass only where no command exists at the place of the throw, and give the reason in the notes.

### Where output goes

Redirect usage and errors by setting the sinks:

```dart
usageOutput: UsageOutputHandler(
  sinks: OutputSinks(out: logger.out, err: logger.err),
),
```

`out` receives usage text such as `--help`. `err` receives usage errors. Completion output has its own sinks on `CompletionSettings`.

A custom `UsageExceptionPrinter` changes the layout of a usage error. The standard printer already writes to `usageOutput.sinks.err`. Sending that standard text to another destination is the `err` sink.

#### Custom printout

The standard printer writes the `message` only. It does not call `toString`. An exception that needs more printed, such as a hint field that the old entry point printed, has two choices:

- The exception puts the text in its `message`. No other change is needed.
- The runner gets a custom exception printer. Choose this when the text has its own place in the output, or when other code reads the field.

A custom printer extends `StandardUsageExceptionPrinter`. It calls `super.printException` for the standard output and then writes the extra text to `usageOutput.sinks.err`:

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
BetterCommandRunner<GlobalOption, int>(
  'app',
  'An example app.',
  globalOptions: GlobalOption.values,
  usageOutput: UsageOutputHandler(
    exceptionSettings: UsageExceptionSettings(
      exceptionPrinter: const AppUsageExceptionPrinter(),
    ),
  ),
);
```

The printer serves every usage error of the runner, also those of the framework. It writes to the sinks of `usageOutput` only, so the output follows the `OutputSinks` of the runner.

For a layout that does not start with the standard output, the printer implements `UsageExceptionPrinter` instead and writes everything.

Test the printer without a command run: call `runner.usageOutput.onUsageException(exception, fromCommand: command)` and read what the `err` sink received. Compare the output with the baseline.

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
    printVersion(context);
    return null;
  }
}

enum GlobalOption<V extends Object> implements OptionDefinition<V> {
  verbose(BetterCommandRunnerFlags.verboseOption),
  version(VersionOption());

  const GlobalOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}
```

- The option is defined on the command where it is valid. A global action option is valid on the runner and after every command.
- It takes the place of a subcommand. A subcommand or another action option after it is a usage error: `<executable> --version <command>` fails, `<executable> <command> --version` runs. Regular options may follow it.
- `--help` is exempt: it is valid anywhere on the line, and with an action option on the same line the usage is printed.
- When it is given, it runs instead of every command. The middlewares run from the root through the command that defines the option, so its `run` reads collaborators from the context like a command does.
- It also runs on an incomplete command line: a missing mandatory option or subcommand is not an error. An unknown option or command still is.
- `context` is the context of the command that defines the option.
- A `version` command that existed next to the option stays, without the `--version` alias. Both call one function that takes the context.
- Compare with the baseline what ran before the old short-circuit. A root middleware that the old code skipped for this option needs the `runsActionOption` guard.
## Entry point

```dart
Future<void> main(List<String> args) async {
  final logger = AppLogger();
  final runner = buildRunner(createApiClient: ApiClient.fromConfiguration);
  try {
    final result = await runner.run(
      args,
      provider: ContextProvider()..store<AppLogger>(logger),
    );
    exit(result ?? 0);
  } on UsageException {
    exit(ExitException.codeError);
  } on ExitException catch (e) {
    exit(e.exitCode);
  }
}
```

- The framework has printed a usage error before `run` throws it. The entry point sets the exit code only.
- Keep the exit codes of the baseline.
- The logger exists before `run`. Seeding it on the provider lets commands read it without taking the runner. A logger that only the sinks and `setLogLevel` use stays with the caller and has no provider slot.
- For a completion request, stdout must hold the completion response only. An entry point that prints after `run` returns sets `completion: CompletionSettings(exitAfterResponse: true)`.

## Tests

- Build the runner with the runner builder that production uses. Pass fakes as the factories.
- Pass `env: const {}` to `run`, or the variables under test. Then the test does not read the environment of the machine.
- Seed with `provider:` and read per-run state back from the same provider after the run:

```dart
final provider = ContextProvider()..store<AppLogger>(logger);

await runner.run(['greet', 'Bob'], env: const {}, provider: provider);

expect(provider.fetch<ApiClient>().closed, isTrue);
```

- Capture usage text with `UsageOutputHandler(sinks: OutputSinks(out: buffer, err: buffer))` and a `StringBuffer`. Capture completion output with `CompletionSettings(sinks: ...)`.
- One runner serves many runs, also concurrent ones, because it holds no state of a run.
- A test that read an object now created during the run reads the provider, or the output.
- Cover each guard of a middleware with the invocations that it separates: a project command, `--help`, an action option, a usage error, and a completion request (`['__complete', '<command>', '--<option>', '']`).
