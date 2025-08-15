[![Serverpod CLI Tools banner](https://github.com/serverpod/cli_tools/raw/main/misc/images/banner-cli-tools.jpg)](https://github.com/serverpod/serverpod)

The cli_tools repository contains open-source packages that help you build CLI commands.  

They are actively maintained and used by the Serverpod team.

## Packages

### cli_tools

The [cli_tools package](packages/cli_tools/) offers several utilities for CLI development, for example: terminal logging, user-input prompting, and usage-analytics collection.

### config

The [config package](packages/config/) provides comprehensive
configuration ingestion and validation, including typed command line options,
environment variables, and configuration files as input, and better error
reporting.


## Contributing Guidelines

To contribute to cli_tools, see the [contribution guidelines](CONTRIBUTING.md).

### Development workflow

This repo uses [melos](https://melos.invertase.dev/) to aid in development,
test, and publishing.

After cloning the repo, run `melos bootstrap` (or `melos bs`) to initialize it
(this will also run `dart pub get`).

Run `melos test` to run all the tests.
