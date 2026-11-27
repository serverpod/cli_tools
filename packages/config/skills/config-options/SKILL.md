---
name: config-options
description: Defines and reads typed command-line options with the Dart `config` package, whose options take their values from arguments, environment variables, and configuration files. Use when writing or changing an `OptionDefinition` enum, an option such as `StringOption` or `FlagOption`, positional arguments, option validation or groups, or a call to `Configuration.resolve`.
---

# Options with the `config` package

An option is defined once, as a typed constant. That one definition serves the command line, environment variables, configuration files, the default, the usage text, and shell completion. A `Configuration` holds the values resolved for one set of options.

```dart
import 'package:config/config.dart';
```

A program with subcommands, `--help`, or shell completion puts its options on the commands of the command framework, `package:config/command.dart` (skill `config-commands`). Options are defined and read there exactly as here, and the framework makes the `Configuration.resolve` call.

## References

- [configuration-files.md](references/configuration-files.md): values from a JSON or YAML file, `configKey`, and a `ConfigurationBroker`.
- [custom-option-types.md](references/custom-option-types.md): an option for a value type that the package does not have, and the completion alternatives of an option value.

The package source is the authority on signatures. After `dart pub get`, take the `config` package root from `.dart_tool/package_config.json` and read:

- `lib/src/config/options.dart`: the doc comment of `ConfigOptionBase` lists what every option supports.
- `lib/src/config/option_types.dart`, `date_time_options.dart`, and `file_system_options.dart`: the option types and the input formats they accept.
- `lib/src/config/configuration.dart`: `Configuration`.
- `example/main.dart`: a complete program.

## Define the options

One generic enum holds the options of one command or program:

```dart
enum Format { text, json }

enum ExportOption<V extends Object> implements OptionDefinition<V> {
  source(
    FileOption(
      argName: 'source',
      argPos: 0,
      mandatory: true,
      mode: PathExistMode.mustExist,
      helpText: 'The file to export.',
    ),
  ),
  format(
    EnumOption(
      enumParser: EnumParser(Format.values),
      argName: 'format',
      argAbbrev: 'f',
      envName: 'EXPORT_FORMAT',
      defaultsTo: Format.text,
      helpText: 'The output format.',
    ),
  ),
  limit(
    IntOption(
      argName: 'limit',
      min: 1,
      helpText: 'The maximum number of records.',
    ),
  ),
  tags(
    MultiStringOption(
      argName: 'tag',
      argAbbrev: 't',
      helpText: 'Export only the records with this tag.',
    ),
  ),
  dryRun(
    FlagOption(
      argName: 'dry-run',
      negatable: false,
      defaultsTo: false,
      helpText: 'Print what would be exported.',
    ),
  );

  const ExportOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}
```

The type parameter `V` carries the value type of each option to the place where it is read, so the reads below need no casts.

### Rules for a definition

- **Constants.** The enum values are constants, so a callback parameter (`fromDefault`, `fromCustom`, `customValidator`) takes the name of a top-level or static function.
- **Guaranteed value.** An option with `mandatory: true` or with a default has a guaranteed value and is read with `value`. Every other option is read with `optionalValue`, which is nullable. An option is either mandatory or has a default, never both.
- **Flags.** A `FlagOption` without a default has three states: `true`, `false`, and null for "not given". Give a plain switch `defaultsTo: false`. A flag also accepts `--no-<name>` unless it has `negatable: false`.
- **Sources.** An option takes values from the sources that its definition names: `argName` (with `argAbbrev` and `argAliases`), `argPos`, `envName`, and `configKey` or `configKeys`. An option with only `envName` is set from the environment only.
- **Positional arguments.** `argPos` starts at 0 and has no gaps. An option with both `argName` and `argPos` accepts either form. When there are several positional options, every one except the last is mandatory and has no `envName` or `configKey`. For a variable number of arguments, see [Resolve and read](#resolve-and-read).
- **Usage text.** Every option with an `argName` has a `helpText`. `valueHelp` names the value (`--port=<integer>`). `hide: true` leaves the option out of the usage and the completion.

### Option types

| Option | Value | Input, and the parameters of the type |
|---|---|---|
| `StringOption` | `String` | `requireNonEmpty` |
| `FlagOption` | `bool` | `--name` and `--no-name`. From the environment or a file: `true` or `false`. `negatable` |
| `IntOption`, `DoubleOption` | `int`, `double` | `min`, `max` |
| `DurationOption` | `Duration` | An integer and one optional unit: `us`, `ms`, `s`, `m`, `h`, `d`. `90s`, `5m`, and `10` (seconds). `min`, `max` |
| `DateTimeOption` | `DateTime` | `2026-11-26`, `2026-11-26T10:30:00Z`. `dateOnly: true` accepts a date only. `min`, `max` |
| `EnumOption<E>` | `E` | The name of an enum value, in the same case. Requires `enumParser: EnumParser(E.values)` |
| `FileOption`, `DirOption` | `File`, `Directory` | `mode`: `PathExistMode.mayExist` (the default), `mustExist`, or `mustNotExist` |
| `MultiStringOption` | `List<String>` | The option repeated (`-t a -t b`), commas (`-t a,b`), or both. `MultiStringOption.noSplit` keeps the commas |
| `MultiOption<T>` | `List<T>` | A list of another type: `multiParser: MultiParser(IntParser())` |

Every type also takes `allowedValues`, with `allowedHelp` for a description of each value. An option that is not a list can be given once on a command line.

For any other value type, write a custom option: [custom-option-types.md](references/custom-option-types.md).

### Computed values

- `fromDefault: _defaultDir` is a default that is computed when the options are resolved, such as the current directory. Add `defaultValueHelp` for the text that the usage shows as the default.
- `fromCustom: _deriveName` derives the value from other options. It runs when the arguments, the environment, and the configuration file gave no value, and a null result falls through to the default. Its parameter is the `Configuration` under construction, where it reads options that are declared before its own option and are not positional.

### Validation

- **One value.** Use the parameters of the type first: `min`, `max`, `allowedValues`, `requireNonEmpty`, `mode`. For any other check, `customValidator` takes a function that throws a `FormatException` for a malformed value and an `InvalidValueException` for a value that is well-formed but not acceptable.
- **Between options.** Options of one command that share a `group: MutuallyExclusive('Target')` constant exclude each other. With `mode: MutuallyExclusiveMode.mandatory`, one of them is required. The options of such a group have no defaults, unless the mode is `allowDefaults`.
- **Usage sections.** A plain `OptionGroup('Output')` puts its options under that heading in the usage.
- **Group names.** A group is identified by its name. Declare each group once, as a constant with a name of its own: groups of the same name that differ in type or mode are a definition error.

## Resolve and read

```dart
void main(List<String> args) {
  final Configuration<ExportOption> config;
  try {
    config = Configuration.resolve(
      options: ExportOption.values,
      args: args,
      env: Platform.environment,
    );
  } on UsageException catch (e) {
    stderr.writeln(e);
    exitCode = 1;
    return;
  }

  final File source = config.value(ExportOption.source);
  final Format format = config.value(ExportOption.format);
  final int? limit = config.optionalValue(ExportOption.limit);
  final List<String>? tags = config.optionalValue(ExportOption.tags);
  final bool dryRun = config.value(ExportOption.dryRun);
  // ...
}
```

- **Sources.** `resolve` reads only the sources it is given: `args`, `env`, and `configBroker`. For each option the first source with a value wins, in this order: named argument, positional argument, environment variable, configuration key, `fromCustom`, default.
- **Where a value came from.** `config.valueSourceType(option)` is a `ValueSourceType`, such as `arg`, `envVar`, `config`, or `defaultValue`. Use it where "the user asked for this" differs from "this is the default".
- **A variable number of arguments.** Pass `ignoreUnexpectedPositionalArgs: true` to `resolve` and read `config.remainingPosArgs`, which holds the words that no positional option took. Without that parameter such words are an error.
- **Errors without an exception.** `Configuration.resolveNoExcept` takes the same parameters and leaves the errors in `config.errors`. Reading an option that has an error then throws an `InvalidParseStateError`.

## Errors

| Error | Meaning | Response |
|---|---|---|
| `OptionDefinitionError` | A mistake in the definitions, such as two options with one name. Thrown by `resolve`, before any value is read. | Fix the definition. |
| `UsageException` | A mistake in the input of the user. One exception holds every error found, in `message`, and the usage text of the options, in `usage`. | Print it and set the exit code. |
| `StateError` from `value` | The option has no guaranteed value. | Read it with `optionalValue`, or give it a default. |

A definition error shows only when the options are resolved. Resolve each new or changed set of options once, in a test or by running the program.

## Tests

- Pass `args` and an explicit `env` map to `resolve`. A source that is not passed is not read, so the test does not depend on the environment of the machine.
- For code that takes a `Configuration`, build one from values: `Configuration<ExportOption>.fromValues(values: {ExportOption.limit: 7, ExportOption.dryRun: false})`. It holds only the options in the map and applies no defaults, so give a value to every option that the code reads.

## Other forms

- A list of constants, `<OptionDefinition>[verbose, name]`, is a set of options too. Each constant keeps its type, so `config.value(name)` is typed. Use it for a set that is composed at run time.
- `ConfigParser` has the interface of `ArgParser` from `package:args`. It is for existing `args` code that changes over step by step. New code defines an enum.
