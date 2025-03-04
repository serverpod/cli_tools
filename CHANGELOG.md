# Changelog

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
