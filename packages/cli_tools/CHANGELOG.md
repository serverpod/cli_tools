## 0.9.1

 - **FEAT**(cli_tools): Make the analytics behavior customizable (#87).

## 0.9.0

> Note: This release has breaking changes.

 - **REFACTOR**(cli_tools): Deprecated CommandDocumentationGenerator (#81).
 - **FEAT**(cli_tools): Enable override of analytics API URL (#85).
 - **BREAKING** **REFACTOR**(cli_tools): Renamed 'target' option to 'tool' (#83).

## 0.8.2

 - **FIX**: Enclose option help in quotes (#77).

## 0.8.0

 - **FEAT**: Command line completion support (#65).
 - **FIX**: Ensure tested up to Dart 3.9 (#62).

## 0.7.1

 - **CHORE**(cli_tools): Bumped `config` dependency.

## 0.7.0
- refactor!: Moved out the `config` library from the `cli_tools` package and into its own package, to be published as `config` on pub.dev.
- fix!: Removed unused static options list in BetterCommandRunner

## 0.6.1
- refactor: Configuration.resolve is a regular constructor instead of a factory constructor

## 0.6.0
- feat!: By default, `Configuration` `resolve` throws an informative `UsageException` on user input error.
- feat: Config library provides usage help text for set of options.

## 0.5.1
- feat: Support specifying a default unit other than seconds in DurationParser.
- docs: Moved config readme into main readme.

## 0.5.0

- feat: Introduced the `config` library for unified args and env parsing
- docs: Added README and code examples for the `config` library
- fix: BREAKING. `BetterCommand` constructor changed to use `MessageOutput` class for clearer specification of logging functions.
- feat: BREAKING. Simplified default usage of `BetterCommand/Runner`
- feat: Subcommands inherit output behavior from their command runner unless overridden
- refactor: The default terminal usage output behavior is now the same as the args package `Command` / `CommandRunner`
- feat: New `Logger.log` method with dynamically specified log level
- fix: Include user input prompt feature in library export
- fix: Downgrade `collection` dependency to 1.18 to be compatible with Dart 3.3
- fix: Replaced `yaml_codec` dependency with `yaml` in order to support Dart 3.3
- chore: Require Dart 3.3

## 0.4.0

- feat: BREAKING. BetterCommandRunner's constructor changed to use MessageOutput class for clearer specification of logging functions.

## 0.3.0

- feat: BREAKING. Logging behavior now allows configuring the log level for stderr. By default, all logs are now directed to stdout.
- feat: BREAKING. Preserves UsageException upon argument parse errors instead of replacing it with ExitException.
- feat: Changed dark red to bright red for console output.

## 0.2.0

- feat: BREAKING. ExitException to handle full range of valid exit codes.

## 0.1.4

- fix: Expose prompt features.

## 0.1.3

- feat: Add prompts module with confirm, select, multiselect and input components.

## 0.1.2

- fix: Don't return ReadException for failed json parsing.

## 0.1.1

- fix: Report analytics event before running command.
- feat: Add documentation generator helper.

## 0.1.0

- feat: Introduce BetterCommand class to simplify command creation.
- fix: BREAKING. Removes onError callbacks from PubApiClient and LocalStorageManager in favor of throwing exceptions.

## 0.0.2

- Downgrades some dependencies to avoid compatibility issues with Serverpod CLI.

## 0.0.1

- Initial version.
