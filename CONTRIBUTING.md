# How to contribute to cli_tools

cli_tools is maintained by Serverpod and is built by the community for the community.
We welcome contributions from everyone, regardless of your experience level.
This document will guide you through the process of contributing to the cli_tools packages.

## Ways to contribute

There are multiple ways to contribute to cli_tools. Here are some of the most common ways:

- **Code**: Contribute code to the cli_tools packages.
- **Documentation**: Contribute to the documentation.
- **Support**: Help others get started or expand their use.
- **File issues**: Suggest new features or improvements.

## Roadmap

If you are considering contributing code, please check the existing issues to see if your contribution is addressed by them, in whole or in part.

## Contributing code

Pull request are very much welcome. If you are working on something more significant than just a smaller bug fix, please declare your interest on an issue first. This way we can discuss the changes to ensure that they align with the project's goals and prevent duplicated work.

### Code style

We use the Dart linter to enforce a consistent code style. The linter is run as part of the CI checks, so it is important that the code follows the linter rules. When you write code, make sure to use `dart format` and `dart analyze` to ensure that the code follows the linter rules.

We try to follow the [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines as much as possible. But above all, we care about code readability and maintainability. Therefore, we encourage you to write code that is easy to read and understand for future contributors.

### Running the tests

To run the tests in a package, set the current directory to it and run `dart test`.

### Introducing new dependencies

Adding new dependencies to the project should be done with care. We are very restrictive with adding new dependencies to the project. If dependencies are added, they must be well maintained, have a permissive open-source license, and must have a good reason for being added.

### Submitting a pull request

All pull requests should be submitted to the `main` branch. The pull request should contain a description of the changes and a reference to the issue that the pull request is addressing.

All code changes should come with tests that validate the changes. If the changes are not testable, please explain why in the pull request.

To keep the projects git history clean, we will squash PRs before merging. Therefore, it is essential that each pull request only contains a single feature or bug fix. Keeping pull requests small also makes it easier to review the changes which in turn speeds up the review process.

Before the Serverpod team can review your pull request, it must pass the CI checks. If the CI checks fail, the pull request will not be reviewed.

## Contributing support

We encourage you to support others using these packages by sharing your knowledge and experiences. You can help by participating in conversations on filed issues, or contributing your insights through tutorials and blog posts.

## Contributing with issues

Help us make these packages better by filing [issue](https://github.com/serverpod/cli_tools/issues/new) for bugs, feature requests, or improvements. When filing an issue, please provide as much information as possible to help us understand the problem or suggestion.
