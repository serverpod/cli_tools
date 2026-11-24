# Old API to new API

Lookup tables for the port (step 4). The package source wins where it differs from a row here.

## Packages and imports

| Old | New |
|---|---|
| `package:args/args.dart`, `package:args/command_runner.dart` | `package:config/config.dart` for options, `Configuration`, and `UsageException`. `package:config/command.dart` for the runner, commands, context, middlewares, usage output, and completion. |
| `Command<T>` from `args` | `BetterCommand<O, T>`. For a command without a class: `CommandImpl.leafWithRunFunction` and `CommandImpl.branch`. |
| `CommandRunner<T>` from `args` | `BetterCommandRunner<O, T>` |

`O` is the option enum of the command or runner. `T` is the result type and must be the same for the runner and all its commands.

## `BetterCommandRunner` constructor

| Old parameter | New |
|---|---|
| `globalOptions` | Unchanged. A global option cannot be positional. |
| `wrapTextColumn: n` | `usageOutput: UsageOutputHandler(usageSettings: UsageSettings(usageLineLength: n))` |
| `messageOutput: MessageOutput(usageLogger:, usageExceptionLogger:)` | `usageOutput: UsageOutputHandler(sinks: OutputSinks(out:, err:))`. For another layout of usage errors: `exceptionSettings: UsageExceptionSettings(exceptionPrinter:)`. |
| `onBeforeRunCommand` | A middleware. See [patterns.md](patterns.md#runner-overrides-and-callbacks). |
| `setLogLevel` | Unchanged. It is not called for completion requests. See [patterns.md](patterns.md#runner-overrides-and-callbacks). |
| `onAnalyticsEvent: (event, properties)` | `onAnalyticsEvent: (context, event, properties)`. `context` is the context of the root command. Its type is nullable; the built-in analytics middleware always passes it. |
| `enableCompletionCommand` | Remove it. Completion is on by default and stays on. `completion: CompletionSettings(...)` changes its settings. |
| `embeddedCompletions` | Removed. The completion scripts hold no commands or options, so nothing is embedded. |
| `suggestionDistanceLimit` | `parserSettings: ParserSettings(suggestionDistanceLimit:)` |
| `env` | `runner.run(args, env: ...)` |
| `usageFooter` getter override | `rootFooter:` |
| (none) | `subcommands:`, `prependMiddlewares:`, `usageGenerator:`, `buildAnalyticsProperties:` |

## `BetterCommandRunner` members

| Old | New |
|---|---|
| `run(args)` | `run(args, env:, provider:)` |
| `globalConfiguration` getter and setter | `context.root().config`. See [patterns.md](patterns.md#per-run-data). |
| `envVariables` | Removed. The environment is passed to `run` and resolved into the configurations. |
| `analyticsEnabled()` | `context.provider.fetch<AnalyticsEnabled>().enabled`, stored by the built-in analytics middleware. |
| `determineAnalyticsSettings()` | `determineAnalyticsSettings(context)`. It is also called for completion requests. |
| `sendAnalyticsEvent(event, [properties])` | `sendAnalyticsEvent(context, event, [properties])`. It no longer checks consent; the caller does. |
| `parse(args)`, `runCommand(argResults)`, `resolveConfiguration(argResults)` | Removed. Code around the run becomes middlewares. Code that changed the parsing becomes option definitions or `parserSettings`. |
| `printUsage()` | `usageOutput.printUsage(runner)` |
| `messageOutput` | Deprecated. `usageOutput`. |
| `addCommand`, `addCommands` | Unchanged. |

## `BetterCommand` members

| Old | New |
|---|---|
| Constructor `messageOutput`, `wrapTextColumn`, `env` | Deprecated and unused. Pass `options` only. |
| `run()` | `run(CommandContext<O, T> context)` |
| `runWithConfig(commandConfig)` | Removed. The command overrides `run(context)` and reads its options from `context.config`. `run` is abstract, also for a branch command. See [patterns.md](patterns.md#base-command). |
| `resolveConfiguration(argResults)` override that adds a configuration source | `configBroker(prevContext)` returning a `ConfigurationBroker`. |
| `argResults`, `globalResults` | `context.config`, `context.root().config` |
| `envVariables` | Removed. |
| `argParser` | `options`, `allOptions()` |
| `runner` (nullable) | Not nullable. Throws `StateError` when the command is not in a runner's tree. |
| `parent` (nullable) | Not nullable. Throws `StateError` when there is no parent. Test `hasParent` first. |
| `name`, `description`, `aliases`, `hidden`, `category`, `summary`, `invocation`, `usageFooter`, `suggestionAliases`, `usage`, `printUsage()`, `usageException(message)` | Unchanged. |

New definition rules, checked when `run` starts, that throw `CommandDefinitionError`:

- A command with subcommands cannot have a positional option.
- A subcommand name or alias cannot equal an option spelling that is valid on its parent command. That includes the global options.
- Two subcommands of one command cannot share a name.

## Parsed arguments

| Old | New |
|---|---|
| `argResults['x']`, `argResults.flag('x')` | `context.config.value(Option.x)`, `optionalValue(Option.x)` |
| `argResults.wasParsed('x')` | `config.valueSourceType(Option.x) == ValueSourceType.arg` |
| The options given on the command line | `config.optionsWhereSource((s) => s == ValueSourceType.arg)`, for each context in the chain. Built-in options such as `--help` are in `context.builtinConfig`. |
| `argResults.rest` | Positional options (`argPos`). For extra words: `ignoreUnexpectedPositionalArgs` and `config.remainingPosArgs`. |
| `topLevelResults.command?.name` | `context.root().next?.command.name` |
| Walk of `argResults.command` | Walk of `context.next`. The last one is `context.leaf()`. |
| `topLevelResults.arguments` | `context.provider.fetch<OriginalCommandLine>().args` |
| A subclass of `Configuration` built in `resolveConfiguration` | `typedef GlobalConfiguration = Configuration<GlobalOption>` and an extension with the typed getters. |

## Command tree

| Old | New |
|---|---|
| `runner.commands` (map; aliases are extra keys) | `runner.subcommands` (list; one entry per command) |
| `command.subcommands['x']` | `command.subcommands.singleWhere((c) => c.name == 'x')` |
| The tree held only the project's commands | Each list also holds a built-in `help` command, and the list of the runner holds the built-in `completion` command. Skip `help` where the old reader did not see it. Keep `completion`: it is a command of the CLI now. |
| `command.hidden`, `command.aliases` on any command | On `BetterCommand` as before. On other `Command` types: `usageDefinition.hidden`, `aliasesDefinition.aliases`. |
| `argParser.options` | `allOptions()`. On the runner it includes the built-in `--help`. |

## Exceptions

| Old | New |
|---|---|
| `UsageException` from `package:args/command_runner.dart` | The same class, imported from `package:config/config.dart`. |
| (none) | `CommandUsageException(message, command)`: the subclass that has the `command`. The framework throws it for errors in the command line, and `usageException(message)` throws it. |
| A project class that extends `UsageException` | It extends `CommandUsageException`, and each throw passes the command. See [patterns.md](patterns.md#project-subclasses-of-usageexception). |
| Entry point code that prints extra fields of a caught usage exception | A custom exception printer on the runner. See [patterns.md](patterns.md#custom-printout). |
| `throw UsageException(message, usage)` in a command | `throw CommandUsageException(message, this)`, or `usageException(message)`. |
| `ArgumentError` from `argParser` for a bad definition | `OptionDefinitionError`, `CommandDefinitionError`. Both are `ConfigDefinitionError`s, thrown by `run` before anything else happens. |

## Completion

| Old | New |
|---|---|
| `CompletionCommand` with the `generate`, `embed`, and `install` subcommands; scripts generated by `completely` or `carapace` | Built-in `completion` command: prints the script for a shell, and `completion install` installs it. `completion --command <name>` makes the script for a wrapper of the executable. |
| Values of an option listed in a generated script | Derived from the option definition when the user presses TAB. A custom completer overrides `complete` on the option; `commandContextOf(completionContext)` gives it the `CommandContext`. |
