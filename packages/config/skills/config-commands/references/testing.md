# Tests of a command-line application

The tests run command lines through the runner, built by the same function that the entry point uses. The examples test the program in [SKILL.md](../SKILL.md#a-complete-program).

```dart
void main() {
  late StringBuffer out;
  late StringBuffer err;
  late CommandRunner<GlobalOption, int> runner;

  setUp(() {
    out = StringBuffer();
    err = StringBuffer();
    runner = buildRunner(out: out, err: err);
  });

  test('greet prints the greeting', () async {
    final result = await runner.run(['greet', 'World'], env: const {});

    expect(result, 0);
    expect(out.toString(), 'Hello World\n');
  });

  test('greet without a name is a usage error', () async {
    await expectLater(
      runner.run(['greet'], env: const {}),
      throwsA(
        isA<UsageException>().having(
          (e) => e.message,
          'message',
          'greet: Option "--name" is mandatory.',
        ),
      ),
    );
    expect(err.toString(), contains('Usage: mytool greet <name>'));
  });

  test('the definitions are valid and --help runs no command', () async {
    final result = await runner.run(['--help'], env: const {});

    expect(result, isNull);
    expect(out.toString(), contains('Usage: mytool'));
  });

  // ...
}
```

## Rules

- **The builder.** Build the runner with the function that production uses. It takes what the tests replace as parameters: sinks, and factories for the objects that middlewares create.
- **The environment.** Pass `env: const {}` to `run`, or the variables under test. Without `env`, `run` reads the environment of the machine.
- **Definition errors.** One test that runs `--help` on the runner validates the whole tree and all options.
- **Usage output.** Capture it with `UsageOutputHandler(sinks: OutputSinks(out: out, err: err))`. A usage error is written to `err` before `run` throws.
- **Follow the test conventions of the host repository** for names and structure.

## Objects of a run

Pass a provider to `run` to seed objects, and read from the same provider after the run what a middleware or a command stored:

```dart
test('a provider seeded by the caller is read back after the run', () async {
  final provider = ContextProvider();

  await runner.run(['-v', 'greet', 'World'], env: const {}, provider: provider);

  expect(provider.fetch<Output>().verbose, isTrue);
});
```

One runner serves many runs, because it holds no state of a run.

## Completion

A completion request is the command line `__complete`, the words typed so far, and the word being completed, which may be empty. The response has one line for each alternative and a final directive line. It is written to the sinks of `CompletionSettings`, which the builder sets to the same buffers.

```dart
test('completion of a command name', () async {
  await runner.run(['__complete', 'gr'], env: const {});

  expect(out.toString(), 'greet\tGreets someone.\n:4\n');
});

test('completion of an option value', () async {
  await runner.run(['__complete', 'greet', '--times', ''], env: const {});

  expect(out.toString(), ':0\n');
});
```

A response with the directive line only, as in the second test, leaves the completion to the shell. Anything else that was written to the `out` sink during the request shows up in the buffer, which is how a test finds a middleware that writes in completion mode.

## Middlewares

Cover each guard of a middleware with the command lines that it separates:

| Command line | Checks that the middleware |
|---|---|
| A command of the application | Does its work |
| `['greet', '--help']` and `['help', 'greet']` | Leaves help alone, also without the mandatory options |
| An action option, such as `['--version']` | Leaves the action option alone |
| `['__complete', 'greet', '--times', '']` | Writes nothing to stdout in completion mode |
| A command line with a usage error | Does not run |

A middleware class is also tested on its own: on a small runner with one command that records what it sees.
