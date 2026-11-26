---
name: cli_tools-migrate-better-command-runner
description: Migrate a Dart CLI built on BetterCommandRunner and BetterCommand from cli_tools 0.14 or older to cli_tools 0.15 which uses config 1.0 (new CommandRunner & Command base classes, CommandContext, middlewares, action options). Use when asked to upgrade cli_tools across that boundary.
disable-model-invocation: true
---

# Migrate a CLI to the new command framework

`cli_tools` 0.15 and `config` 1.0 replace the `package:args` command runner. The new framework builds the command tree once and passes the data of each run in a `CommandContext`.

This skill ports a CLI to the new API and then moves its code onto the new constructs. Code that compiles against the new API is the midpoint (step 4), not the result.

## Target

The migration is done when all four statements hold.

1. **Shared run data is on the context.** Option values are read from `context.config` and the `prev` chain. An object created during `run` and read from more than one place is on `context.provider`. An object that exists when the runner is constructed may stay on the runner. The provider is the convenient place for it when commands would otherwise take the runner to reach it. Runner and command classes hold definitions (names, descriptions, options, subcommands, middlewares, output settings) and those construction-time objects.
2. **Cross-cutting logic is in middlewares.** Logic that serves more than one command runs in a middleware: setup and teardown, login and mode checks, error mapping, update checks. Each middleware has one responsibility. A command's `run` contains the work of that command only.
3. **Option-style commands are action options.** An argument that is written as an option and runs like a command, such as `--version`, is an option definition with `ActionOptionMixin`.
4. **The CLI behaves as before.** The only differences are the ones the framework forces, and the ones the person running the migration decided.

## References

- [api-map.md](api-map.md): each old member and its replacement.
- [patterns.md](patterns.md): the target structures with code, and the rules that decide where a piece of logic goes.
- [behavior-changes.md](behavior-changes.md): the baseline invocations, which invocations reach which hook, and the forced CLI changes.

The package source is the authority on signatures. After `dart pub get`, take the `config` and `cli_tools` package roots from `.dart_tool/package_config.json` and read:

- `config`: `README_command.md`, the class doc of `CommandRunner` in `lib/src/command/command_runner.dart` (phases and error handling), and `example/command_example.dart`.
- `cli_tools`: `lib/src/better_command_runner/better_command_runner.dart` and `example/main.dart`.

## Steps

Keep the working notes (baseline, inventory, decisions) in one scratch directory outside the repository.

Change the tests in the same step as the code they cover. See [patterns.md](patterns.md#tests).

Follow the commit rules of the host repository. Steps 4 to 8 are separate logical changes. The dependency bump and the port in step 4 compile only together.

### 1. Take inventory

Read the runner subclass, the base command classes, the entry point, and the tests' setup helpers. Write `inventory.md` in the scratch directory, one row per item with file and line:

| Group | What to list |
|---|---|
| A. Per-run state | Every instance field of the runner and command classes that is assigned after construction, or that holds an object used during a run: global configuration, analytics consent, logger, clients, service providers, resolved paths. Also the getters that expose them, and their callers. For each object, note whether it exists before `run` or is created during `run`, and how many places read it. |
| B. Cross-cutting logic | Runner overrides: `run`, `runCommand`, `parse`, `resolveConfiguration`, `printUsage`, `determineAnalyticsSettings`, `sendAnalyticsEvent`. Constructor callbacks: `onBeforeRunCommand`, `setLogLevel`, `onAnalyticsEvent`, `messageOutput`. In the base command classes: everything in `run` or `runWithConfig` that runs before, after, or around the hook that subclasses implement. |
| C. Option-style commands | Options that the runner tests in order to do something and skip the command. Commands whose name or alias starts with `-`. |
| D. `package:args` API | `ArgResults`, `argResults`, `globalResults`, `argParser`, `wasParsed`, the `.command` chain, `.rest`, `.arguments`. |
| E. Usage exceptions | Classes that extend `UsageException`. Each place that throws a `UsageException` or one of those classes. The code that prints a caught `UsageException`, and which of its fields it prints. |
| F. Command tree readers | Scripts, doc generators, and tests that read `runner.commands`, `subcommands[...]`, or `argParser.options`. |
| G. Completion | `enableCompletionCommand`, `embeddedCompletions`, completion scripts, install tasks, user docs. |
| H. Descriptions | READMEs, contributor docs, and agent rules that describe the runner and command structure. |

Give each row in groups A to C a destination: stays as a definition, a final field of the runner, `context.config`, `context.provider`, a middleware (which one, and where in the order), an action option, the `run` of one command, stays as an override or a callback, or deleted. [patterns.md](patterns.md) has the rules.

For each row in group B, also write which invocations reached that code before. Use the table in [behavior-changes.md](behavior-changes.md#which-invocations-reach-which-hook).

Done when every field, override, and callback of the runner and base command classes has a row with a destination, and every group B row has its reach.

### 2. Record option collisions

Check every spelling of every option against the options of every command below it: the `--name`, the abbreviation, each alias, and the `--no-name` form of a negatable flag.

A subcommand option with the same spelling shadows the parent option. Leave both definitions in place and record the collision for the report. Shadowing is per spelling:

- After the subcommand, that spelling sets the subcommand's option.
- Before the subcommand, and through spellings the subcommand does not define, it sets the parent option.
- A non-persistent option hides the spelling only on the command that defines it, so a further nested command sees the parent spelling again.
- A persistent option hides the spelling for that command and every command below it, until another option shadows it.

Write each collision in the notes: the parent option, the subcommand option, and the shared spellings. Step 10 lists them.

A command name or alias that equals an option spelling is a different case. When that option is valid on the parent command, global options included, the runner throws a `CommandDefinitionError` at startup. Step 4 removes the usual case, an alias such as `--version`, when it converts that command to an action option. Ask about any other case.

Done when each option collision is in the notes with its shared spellings, or the check found none, and each remaining command-name clash has a decision.

### 3. Record the baseline

Steps 1 and 2 edit nothing, so the code is still unmigrated. If `pubspec.yaml` already requires `cli_tools` 0.15, that code does not compile: record the baseline in a git worktree of the last commit before that change.

1. Run the analyzer and the tests. Note every failure that exists already.
2. Capture stdout, stderr, and the exit code of the invocations listed in [behavior-changes.md](behavior-changes.md#baseline-invocations).

Done when the scratch directory has one capture per listed invocation, and a note for each invocation that was skipped and why.

### 4. Port to the new API

1. Set `cli_tools` to 0.15 and `config` to 1.0 in `pubspec.yaml`. Use the newest published versions, pre-releases included. Both packages need Dart SDK 3.9 or later. Remove `args` when no other code imports it.
2. Replace each old member with its entry in [api-map.md](api-map.md). This covers group D, and it moves `env` from the runner constructor to `run`.
3. Delete `invocation` overrides that restate the generated synopsis. The api-map row says when to keep one.
4. Change each class that extends `UsageException` (group E) to extend `CommandUsageException`, and pass the command at each throw. Remove the entry point code that prints a caught `UsageException`: the framework prints it now. Where that code printed more than the message, such as a hint field, put that text in the message or give the runner a custom exception printer. Code that only sent the usage or the error somewhere else sets `OutputSinks.out` and `OutputSinks.err`. See [patterns.md](patterns.md#project-subclasses-of-usageexception) and [patterns.md](patterns.md#where-output-goes).
5. Apply a command-name change decided in step 2.
6. Update the tests for the forced changes in [behavior-changes.md](behavior-changes.md#forced-changes) only.

Where an old member has no direct replacement, build the target structure from [patterns.md](patterns.md) now, not an interim bridge. This pulls work of steps 5 to 7 into this step. Two cases always do:

- An option test with an early return in a `runCommand` override. The override is removed, so the option becomes an action option now.
- A command name or alias that equals an option spelling, such as `--version`. The runner throws at startup until the command is an action option.

Steps 5 to 7 then finish what is left and check all of it against their done criteria.

Done when all of these are true:

- `dart analyze` reports no errors, and the tests pass apart from the failures noted in step 3. Deprecation warnings from `cli_tools` are expected at this point.
- No class of the project extends `UsageException` directly, or the notes give the reason for each one that does.

### 5. Move per-run data to the context

Work through group A of the inventory. See [patterns.md](patterns.md#per-run-data).

1. Give each object the place the table in [patterns.md](patterns.md#per-run-data) names.
2. Create an object that is born during `run` in the middleware that owns it. Store it on the provider when more than one place reads it.
3. Read a provider value through a function in that file. Use an extension on `CommandContext` when other files read it too.
4. Remove fields and constructor parameters that carried an object created during `run`. An object that exists before `run` may stay a final field of the runner.

Done when all of these are true:

- Every instance field of the runner and command classes is `final` and is set in the constructor.
- Every object created during `run` and read from more than one place is on `context.provider`.
- A command reads an object created during `run` from `context.provider` or from a local variable.
- A command constructor takes no object that is created during `run`.

### 6. Move cross-cutting logic to middlewares

Work through group B of the inventory. See [patterns.md](patterns.md#middlewares).

1. Turn each part of the base command's wrapper into its own middleware on the runner. Keep the order that the wrapper had. Setup and teardown of one object stay in one `withHooks`. See [patterns.md](patterns.md#one-responsibility).
2. Give each runner override and constructor callback the replacement in the table in [patterns.md](patterns.md#runner-overrides-and-callbacks).
3. Guard each middleware so that it acts for the same invocations as the code it replaces. See [patterns.md](patterns.md#reach-and-guards).

Done when all of these are true:

- The runner subclass overrides no method of the run flow. `determineAnalyticsSettings` is the one exception.
- The base command class has no code that runs before, after, or around the work of a subclass. Each leaf command overrides `run(context)` directly, with no hook method of the project in between.
- The runner constructor gets none of `onBeforeRunCommand`, `messageOutput`, `wrapTextColumn`, `enableCompletionCommand`, `embeddedCompletions`, `env`.
- `dart analyze` reports no deprecation warning from `cli_tools` or `config`.
- Each group B row names its middleware or its other replacement, and a test covers each guard.

### 7. Convert option-style commands to action options

Work through group C of the inventory. See [patterns.md](patterns.md#action-options). Step 4 already converted the rows that could not wait; convert the rest, and add the tests for all of them.

Done when all of these are true:

- No command name or alias starts with `-`.
- No middleware and no command tests an option value in order to skip the command.
- Tests run each action option alone, before a subcommand, after a subcommand, and on a command line with a mandatory option missing.

### 8. Update the entry point, completion, tools, and descriptions

1. Entry point: pass `provider:` when a command reads a construction-time object from the context, and set only the exit code for a caught `UsageException`. See [patterns.md](patterns.md#entry-point).
2. Completion (group G): leave completion enabled, which is the default. Remove the embedded scripts and their generators, and change install tasks and user docs to `completion install`. A CLI that had no completion command gets the built-in one; name that in the report.
3. Command tree readers (group F): port them with [api-map.md](api-map.md#command-tree), then run them and compare their output with the baseline.
4. Descriptions (group H): rewrite the parts that describe the old structure.

Done when the scripts and tasks in groups F and G run, and no file in group H names a removed member.

### 9. Verify

1. `dart analyze` reports no issues. `dart format` leaves the changed files unchanged.
2. No runner, command, or test of them imports `package:args`, and no group D row is left.
3. The tests pass, apart from the failures noted in step 3.
4. Capture the baseline invocations again and compare them with step 3. Each difference is a forced change, a command-name change decided in step 2, a kept `invocation` override, or the shadowing of a collision recorded in step 2. Anything else is a defect to fix.
5. Request an option value completion (`<executable> __complete <command> --<option> ''`) for one option with a custom completer and one without. Nothing but the completion response is written to stdout, nothing prompts, and no analytics event is sent.
6. Read the done criteria of steps 5 to 7 once more against the final code.

Done when all six pass.

### 10. Report

Tell the person running the migration:

- each CLI-visible difference from the baseline, with the invocation that shows it,
- each option collision from step 2: the shared spellings, and that the subcommand option shadows the parent,
- each command-name clash decided in step 2, and where it was applied,
- each `invocation` override that was kept, and why,
- each exception to a done criterion that the notes record, with its reason,
- each baseline invocation that was skipped, and anything else that is not verified.
