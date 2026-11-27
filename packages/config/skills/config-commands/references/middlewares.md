# Middlewares and the objects of one run

`ApiClient`, `AppException`, and `AppCommand` stand for the types of the application. The result type of the runner is `int` in the examples.

- [Forms](#forms)
- [Order](#order)
- [Reach and guards](#reach-and-guards)
- [Objects of one run](#objects-of-one-run)
- [Error mapping](#error-mapping)

## Forms

Each middleware has one responsibility. A login check, an error mapping, and the creation of a client are three middlewares. The setup and the teardown of one object are one responsibility and share one `withHooks`.

| Form | Use |
|---|---|
| `Middlewares.onBeforeRun((context) { ... })` | Runs before. Keeps the context. |
| `Middlewares.onRun((context) => context)` | Runs before. Returns the context to pass on, for example from `copyWith`. |
| `Middlewares.onReturn((context, result) => result)` | Runs after a normal return. Returns the result to pass back. |
| `Middlewares.onError((error, stackTrace, context) => ...)` | Runs after a throw. Returns a result to recover, or throws. |
| `Middlewares.onFinally((context) { ... })` | Runs last in both cases. Its own errors are ignored. |
| `Middlewares.withHooks(onRun:, onReturn:, onError:, onFinally:)` | The setup and teardown of one responsibility. |
| `class X extends CommandMiddlewareHooks<O, T>`, used as `X().middleware` | A named unit with its own tests. |
| `(next) => (context) async { ...; return next(context); }` | The raw form. Only this form can skip the rest of the run and return normally, by not calling `next`. |

The class form overrides the hooks that it needs. What it depends on comes in through its constructor. What it creates during a run goes on the provider, because one middleware object serves every run:

```dart
/// Reports how long the run of a command took.
class TimingMiddleware<O extends OptionDefinition>
    extends CommandMiddlewareHooks<O, int> {
  const TimingMiddleware(this.report);

  final void Function(String command, Duration elapsed) report;

  @override
  CommandContext<O, int> onRun(CommandContext<O, int> context) {
    if (executedCommand(context) != null) {
      context.provider.store(Stopwatch()..start());
    }
    return context;
  }

  @override
  void onFinally(CommandContext<O, int> context) {
    final stopwatch = context.provider.maybeFetch<Stopwatch>();
    if (stopwatch == null) return;
    report(context.leaf().command.name, stopwatch.elapsed);
  }
}
```

`O` is the option type of the command that the middleware is on. On the runner it is the enum of the global options: `TimingMiddleware<GlobalOption>(report).middleware`.

## Order

The `onRun` hooks run in this order:

1. The middlewares of the runner: the `middlewares:` list in list order, then those added with `addMiddleware`.
2. The middlewares of each further command on the command line, from the root to the last command.
3. The `run` of the last command, or of the action option.

The `onReturn`, `onError`, and `onFinally` hooks run in the reverse order.

- An `onError` hook sees the errors of everything inside it: the later middlewares and the command. It does not see the errors of earlier middlewares or of its own `onRun`.
- An `onFinally` hook runs when the `onRun` of the same middleware has completed. That is why the setup and the teardown of one object share one `withHooks`.

## Reach and guards

| Command line | Middlewares of the runner | Middlewares of the other commands on the line | Command `run` |
|---|---|---|---|
| A command of the application, on a valid command line | Yes | Yes | The last command only |
| `--help` or `-h`, anywhere on the line | Yes | No | No |
| `help <command>` | Yes. `context.leaf().command` is a built-in help command. | Those of the commands before `help` | No |
| No arguments, on a runner with `canRunAsLeafCommand: true` | Yes. `context.leaf().command` is the runner. | | The `runAsLeaf` of the runner, which prints the usage. |
| A global action option | Yes | No | No |
| An action option of a command | Yes | From the root through the command that defines it | No |
| The built-in `completion` command | Yes | | Built-in |
| A completion request for an option value | Yes. `context.runMode` is `CommandRunMode.completion`. | Yes | No |
| A completion request for a command name or an option name | No | No | No |
| A usage error: an unknown command or option, a missing or invalid value, a missing subcommand | No | No | No |

Choose the guard by what the middleware does:

| The middleware | Guard |
|---|---|
| Stores an object that commands or option completers read. No output, no prompt. | None |
| Reads a mandatory option | `if (context.config.errors.isEmpty)` around the read. On the incomplete command lines of help, action options, and completion, the option may be missing, and reading it throws an `InvalidParseStateError`. |
| Writes output, prompts, or does slow work | Returns at once when `context.runMode == CommandRunMode.completion`. Stdout carries the completion response then. |
| Applies when a command of the application runs: a login check, an update check, timing | `executedCommand(context)` below |

`executedCommand` needs a base class for the commands of the application:

```dart
abstract class AppCommand<O extends OptionDefinition>
    extends CommandImpl<O, int> {
  AppCommand({required super.name, required super.description, super.options});

  /// Whether the command needs a logged in user.
  bool get requireLogin => true;
}

/// Whether an action option, such as `--help`, runs instead of a command.
bool runsActionOption<T>(CommandContext<OptionDefinition, T> context) {
  CommandContext<OptionDefinition, T>? current = context.root();
  while (current != null) {
    if (current.specifiedActionOptions().isNotEmpty) return true;
    current = current.next;
  }
  return false;
}

/// The application command that this run executes, or null when the run
/// prints help, runs an action option, or serves a completion request.
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

A property of a command, such as `requireLogin`, is a definition and stays on the command class. The middleware reads it:

```dart
Middlewares.onBeforeRun((context) async {
  final command = executedCommand(context);
  if (command == null || !command.requireLogin) return;
  if (!await context.apiClient.isLoggedIn()) {
    throw AppException('Log in first.');
  }
}),
```

`specifiedActionOptions()` covers one context, so `runsActionOption` walks the chain.

## Objects of one run

| The object | Where it lives |
|---|---|
| Exists before `run`, such as a logger of the entry point | The caller stores it on a provider and passes that to `run`: `runner.run(args, provider: ContextProvider()..store<Logger>(logger))`. |
| Is created from the resolved options, and several commands read it | A middleware creates it, stores it on `context.provider`, and releases it in the `onFinally` of the same `withHooks`. |
| Is created and read by one command | A local variable in its `run`. |

```dart
Middlewares.withHooks(
  onRun: (context) {
    final server = context.config.value(GlobalOption.server);
    context.provider.store(createApiClient(server));
    return context;
  },
  onFinally: (context) => context.provider.fetch<ApiClient>().close(),
),
```

`createApiClient` is a parameter of the function that builds the runner. Tests pass a function that returns a fake.

The provider is keyed by the type argument:

- `store<Logger>(StdoutLogger())` is read with `fetch<Logger>()`. Give `store` the type argument whenever the value is a subtype or a fake.
- `fetch` throws a `ContextValueNotFound`. Use `maybeFetch` where an empty slot is a valid state, such as in an `onFinally` whose `onRun` stores the object only sometimes.
- Two values of one type share a slot. A derived value, such as a resolved project directory, gets its own class.

When several commands read the same values, an extension on `CommandContext` gives them getters:

```dart
extension AppContext<O extends OptionDefinition, T> on CommandContext<O, T> {
  String get server => root().config.value(GlobalOption.server);

  ApiClient get apiClient => provider.fetch<ApiClient>();
}
```

## Error mapping

```dart
Middlewares.onError((error, stackTrace, context) {
  if (error is! AppException) {
    Error.throwWithStackTrace(error, stackTrace);
  }
  stderr.writeln('Error: ${error.message}');
  return 1;
}),
```

- It is the first middleware of the runner, so that it also maps the errors of the middlewares after it.
- It maps the failures that the application expects, and rethrows everything else unchanged. A `UsageException` goes on to the framework, which prints it. A bug stays visible with its stack trace.
- The returned value is the result of `run`, here the exit code.
