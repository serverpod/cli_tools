# A program without subcommands

A program that does one thing is a `CommandRunner` without subcommands. A subclass of the runner holds the options and the work. The program still gets `--help`, usage errors, middlewares, and shell completion.

```dart
enum CatOption<V extends Object> implements OptionDefinition<V> {
  file(
    FileOption(
      argName: 'file',
      argPos: 0,
      mandatory: true,
      mode: PathExistMode.mustExist,
      helpText: 'The file to print.',
    ),
  ),
  number(
    FlagOption(
      argName: 'number',
      argAbbrev: 'n',
      negatable: false,
      defaultsTo: false,
      helpText: 'Number the lines.',
    ),
  );

  const CatOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

class CatRunner extends CommandRunner<CatOption, int> {
  CatRunner({StringSink? out, StringSink? err})
    : super(
        'cat',
        'Prints a file.',
        usageOutput: UsageOutputHandler(sinks: OutputSinks(out: out, err: err)),
      ) {
    CatOption.values.forEach(addOption);
  }

  @override
  Future<int> runAsLeaf(CommandContext<CatOption, int> context) async {
    final file = context.config.value(CatOption.file);
    final number = context.config.value(CatOption.number);
    final lines = await file.readAsLines();
    for (final (index, line) in lines.indexed) {
      _out.writeln(number ? '${index + 1}  $line' : line);
    }
    return 0;
  }
}

Future<void> main(List<String> args) async {
  try {
    exitCode = await CatRunner().run(args) ?? 0;
  } on UsageException {
    exitCode = 1;
  }
}
```

- **Options.** The constructor adds the options with `addOption`. Options added this way may be positional, which `globalOptions:` does not allow.
- **Work.** `runAsLeaf` is the `run` of the runner. The inherited one prints the usage.
- **Completion.** A runner without subcommands has the built-in option `--completion <shell>`, which prints the completion script. The `completion` command exists only on a runner with subcommands.

When the program gets a second task, turn the work into a command and give the runner subcommands, as in [SKILL.md](../SKILL.md#a-complete-program).
