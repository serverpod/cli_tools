# Target patterns

`AppCommand`, `AppLogger`, `AppUsageException`, `ApiClient`, and `GlobalOption` stand for the project's own types. The result type of the runner is `int` in the examples.

- [Per-run data](#per-run-data)
- [Middlewares](#middlewares): forms, order, reach and guards, base command, runner overrides, usage errors
- [Action options](#action-options)
- [Entry point](#entry-point)
- [Tests](#tests)

## Per-run data

### Read through a context extension

```dart
typedef GlobalConfiguration = Configuration<GlobalOption>;

extension AppContext<O extends OptionDefinition, T> on CommandContext<O, T> {
  GlobalConfiguration get globalConfiguration =>
      root().config as GlobalConfiguration;

  AppLogger get logger => provider.fetch<AppLogger>();

  ApiClient get apiClient => provider.fetch<ApiClient>();
}
```

- `context.config` holds the options of the command itself. `context.root().config` holds the global options. The contexts of the commands before it are on `prev`.
- The provider is keyed by the type argument. `store<AppLogger>(StdOutAppLogger())` is read with `fetch<AppLogger>()`. Give `store` the type argument whenever the value is a subtype or a fake.
- `fetch` throws `ContextValueNotFound`. Use `maybeFetch` where an empty slot is a valid state.
- A value derived during the run, such as a resolved project directory, gets its own class, is stored by a middleware, and gets a getter in the extension. Two values of one type would share a slot.
- Typed getters for global options go in an extension on `Configuration<GlobalOption>`.

### Where a per-run object is created

| The object is needed | Create it | Then |
|---|---|---|
| While middlewares and commands run. This is the default. | In a middleware, from `context.config` and a factory that the runner builder received. | Store it on the provider. Release it in `onFinally` of the same middleware. |
| During resolution (in `configBroker`), or by the caller before and after `run`: the logger of the entry point, for example. | By the caller, which passes `provider:` to `run`. | The same provider serves a completion request. |
| By an option completer. | In a middleware that also runs for completion requests, or by the caller. | No output and no prompt in completion mode. |

Usage and completion output are static settings of the runner (`UsageOutputHandler`, `CompletionSettings`). When usage text must go through a logger, the code that builds the runner passes sink adapters for that logger to `OutputSinks`. This is the one place where an object of a run is fixed at construction.

A middleware-created object:

```dart
BetterCommandRunner<GlobalOption, int> buildRunner({
  required final ApiClient Function(GlobalConfiguration) createApiClient,
}) {
  return BetterCommandRunner<GlobalOption, int>(
    'app',
    'An example app.',
    globalOptions: GlobalOption.values,
    prependMiddlewares: [
      Middlewares.withHooks(
        onRun: (final context) {
          context.provider.store<ApiClient>(createApiClient(context.config));
          return context;
        },
        onFinally: (final context) => context.apiClient.close(),
      ),
    ],
  );
}
```

The builder takes factories, never instances that belong to a run. Tests pass a factory that returns a fake.

`configBroker` runs during resolution, before every middleware. It sees the configurations of the commands before it, and what the caller seeded:

```dart
@override
ConfigurationBroker? configBroker(
  final CommandContext<OptionDefinition, int>? prevContext,
) {
  if (prevContext == null) return null;
  return projectFileBroker(
    directory: prevContext.globalConfiguration.value(GlobalOption.projectDir),
    logger: prevContext.logger,
  );
}
```

## Middlewares

### Forms

| Form | Use |
|---|---|
| `Middlewares.onBeforeRun((context) { ... })` | Runs before. Cannot replace the context. |
| `Middlewares.onRun((context) => context)` | Runs before. Returns the context to pass on, for example from `copyWith`. |
| `Middlewares.onReturn((context, result) => result)` | Runs after a normal return. Returns the result to pass back. |
| `Middlewares.onError((error, stackTrace, context) => ...)` | Runs after a throw. Returns a result to recover, or throws. |
| `Middlewares.onFinally((context) { ... })` | Runs last in both cases. Its own errors are ignored. |
| `Middlewares.withHooks(onRun:, onReturn:, onError:, onFinally:)` | Hooks that belong together, such as setup and teardown. |
| `class X extends CommandMiddlewareHooks<O, T>`, used as `const X().middleware` | A named unit with its own tests. Construction-time dependencies are constructor fields; per-run state goes on the provider. |
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
- Teardown shares one `withHooks` with its setup. Then `onFinally` runs only when that setup ran.

### Reach and guards

A root middleware runs for every valid command line, not only when a project command runs. It also runs for `--help`, `help <command>`, action options, the root usage, the built-in `completion` command, and completion requests for an option value. It does not run when the command line has a usage error. The full table is in [behavior-changes.md](behavior-changes.md#which-invocations-reach-which-hook).

Code that moved from a base command ran only when a project command ran. Give it that reach again:

```dart
extension AppRun<O extends OptionDefinition, T> on CommandContext<O, T> {
  /// Whether an action option, such as `--help`, runs instead of a command.
  bool get runsActionOption {
    CommandContext<OptionDefinition, T>? context = root();
    while (context != null) {
      if (context.specifiedActionOptions().isNotEmpty) return true;
      context = context.next;
    }
    return false;
  }

  /// The project command that this run executes, or null when the run prints
  /// help, runs an action option, or serves a completion request.
  AppCommand? get executedCommand {
    if (runMode == CommandRunMode.completion || runsActionOption) return null;
    return switch (leaf().command) {
      final AppCommand command => command,
      _ => null,
    };
  }
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
| A check before the command (login, required mode) that depends on a property of the command | `Middlewares.onBeforeRun` on the runner, which reads the property from `context.executedCommand` |
| A helper object built for the command, such as an output formatter | A middleware stores it on the provider; the context extension gets a getter |
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
  FutureOr<int?> run(final CommandContext<O, int> context) =>
      throw UnsupportedError('Branch command $name should not be run.');
}

class GreetCommand extends AppCommand<GreetOption> {
  GreetCommand() : super(options: GreetOption.values);

  @override
  String get name => 'greet';

  @override
  String get description => 'Greets someone.';

  @override
  Future<int?> run(final CommandContext<GreetOption, int> context) async {
    final name = context.config.value(GreetOption.name);
    context.logger.info('Hello $name, from ${context.apiClient.url}');
    return 0;
  }
}
```

The wrapper parts as middlewares, in the order the wrapper had:

```dart
runner.addMiddleware(
  Middlewares.onError((final error, final stackTrace, final context) {
    if (error is UsageException || error is ExitException) {
      Error.throwWithStackTrace(error, stackTrace);
    }
    context.logger.error('${context.leaf().command.name} failed: $error');
    throw ExitException.error();
  }),
);

runner.addMiddleware(
  Middlewares.onBeforeRun((final context) async {
    final command = context.executedCommand;
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
| `setLogLevel` that sets the level on a captured logger | A middleware, first in `prependMiddlewares`, that reads `context.config` and sets the level on `context.logger`. It returns at once in completion mode. Do not pass `setLogLevel`. |
| `determineAnalyticsSettings()` | Stays an override; it is the extension point for consent. It takes the context, reads what position 1 middlewares stored, and returns false first when `context.runMode` is `CommandRunMode.completion`. |
| `sendAnalyticsEvent` override, `analyticsEnabled()` override | Move the logic into the `onAnalyticsEvent` callback and `determineAnalyticsSettings`. |
| `messageOutput` | `usageOutput`. See [api-map.md](api-map.md). |

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
    final UsageException exception, {
    required final UsageOutputHandler usageOutput,
    final CommandDefinition? fromCommand,
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
    final CommandContext<O, R> context,
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

- The option is defined on the command where it is valid. A global action option is valid anywhere on the command line.
- When it is given, it runs instead of every command. The middlewares run from the root through the command that defines the option, so its `run` reads collaborators from the context like a command does.
- It also runs on an incomplete command line: a missing mandatory option or subcommand is not an error. An unknown option or command still is.
- `context` is the context of the command that defines the option.
- A `version` command that existed next to the option stays, without the `--version` alias. Both call one function that takes the context.
- Compare with the baseline what ran before the old short-circuit. A root middleware that the old code skipped for this option needs the `runsActionOption` guard.
- `BetterCommandRunner` sends the analytics event of a global action option under the name of the option, such as `--version`.

## Entry point

```dart
Future<void> main(final List<String> args) async {
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

- The framework prints every usage error to `usageOutput.sinks.err` before `run` throws it, also one that a command or a middleware threw. The entry point sets the exit code only.
- Keep the exit codes of the baseline.
- For a completion request, stdout must hold the completion response only. An entry point that prints after `run` returns sets `completion: CompletionSettings(exitAfterResponse: true)`.

## Tests

- Build the runner with the builder that production uses. Pass fakes as the factories.
- Pass `env: const {}` to `run`, or the variables under test. Then the test does not read the environment of the machine.
- Seed with `provider:` and read per-run state back from the same provider after the run:

```dart
final provider = ContextProvider()..store<AppLogger>(logger);

await runner.run(['greet', 'Bob'], env: const {}, provider: provider);

expect(provider.fetch<ApiClient>().closed, isTrue);
```

- Capture usage text with `UsageOutputHandler(sinks: OutputSinks(out: buffer, err: buffer))` and a `StringBuffer`. Capture completion output with `CompletionSettings(sinks: ...)`.
- One runner serves many runs, also concurrent ones, because it holds no state of a run.
- A test that read a field of the runner or of a command now reads the provider, or the output.
- `help <command>` does not find a hidden command. Use `<command> --help`.
- Cover each guard of a middleware with the invocations that it separates: a project command, `--help`, an action option, a usage error, and a completion request (`['__complete', '<command>', '--<option>', '']`).
