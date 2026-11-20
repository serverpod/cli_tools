## 1.0.0-beta.0

 - **FEAT**(command): Accept arguments after -- via parser settings ([#145](https://github.com/serverpod/cli_tools/issues/145)). ([df6feaef](https://github.com/serverpod/cli_tools/commit/df6feaefae37b0b142a9b6580b4828513184cd2a))
 - **FEAT**(command): Subcommands now shadow parents' options ([#138](https://github.com/serverpod/cli_tools/issues/138)). ([ac22c745](https://github.com/serverpod/cli_tools/commit/ac22c7452e4657c95a9130658868bc6ed61edc6e))
 - **FEAT**(command): New CommandRunner framework ([#134](https://github.com/serverpod/cli_tools/issues/134)). ([b628aa8f](https://github.com/serverpod/cli_tools/commit/b628aa8f1d1400f97b33016b7e3bf8054c1b683a))
 - **FEAT**(config): Improvements to options parsing and error handling ([#139](https://github.com/serverpod/cli_tools/issues/139)). ([4791ea17](https://github.com/serverpod/cli_tools/commit/4791ea171ac4a4cc7c943659673a234f7243b467))
 - **FEAT**(config): Prepare config for new CommandRunner framework ([#133](https://github.com/serverpod/cli_tools/issues/133)). ([dec5d7e0](https://github.com/serverpod/cli_tools/commit/dec5d7e01de441e71b772f136b05d8f8d293acbf))
 - **DOCS**(config): Introducing command framework ([#146](https://github.com/serverpod/cli_tools/issues/146)). ([589e868e](https://github.com/serverpod/cli_tools/commit/589e868ef9ac992216bec1d8d2a23b0f18c08bb8))

## 0.10.0

> Note: This release has breaking changes.

 - **FEAT**(config): New command line arguments parser ([#130](https://github.com/serverpod/cli_tools/issues/130)). ([aa1d64e5](https://github.com/serverpod/cli_tools/commit/aa1d64e55922dc77e2adb5d87bc67ae759a26595))
 - **FEAT**(config): A findOption method, and expose unparsed args ([#129](https://github.com/serverpod/cli_tools/issues/129)). ([18b18a1d](https://github.com/serverpod/cli_tools/commit/18b18a1d67661caeaba97c6f1034e91a3a4d847f))
 - **BREAKING** **CHORE**: Bumped min Dart SDK version to 3.9.0 ([#131](https://github.com/serverpod/cli_tools/issues/131)). ([712e19ac](https://github.com/serverpod/cli_tools/commit/712e19aca0856f83f1f04f91db9018e5eda6e04b))

## 0.9.1

 - **FEAT**(config): Support multiple configuration sources for an option (#127).

## 0.9.0

 - Bumped minimum Dart SDK version to 3.6

## 0.8.4

 - **FIX**(config): Created a public OptionResolution interface (#91).

## 0.8.3

 - **FIX**(config): Improved doc comments & value formatting of options (#82).
 - **FIX**(config): Validation Logic for Configuration File Extension (#76).

## 0.8.2

 - **FEAT**: Support for Option Group Name (#71).

## 0.8.0

 - **FEAT**: multiParser getter in MultiOption (#67).
 - **FIX**: Ensure tested up to Dart 3.9 (#62).

## 0.7.2

 - **DOCS**(config): Corrected GitHub links in README.

## 0.7.1
- docs: Corrected BetterCommand references and links in README

## 0.7.0
- feat: Moved out the `config` library from the `cli_tools` package and into its own package, to be published as `config` on pub.dev.
