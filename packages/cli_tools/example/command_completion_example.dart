import 'dart:io' show exitCode;

import 'package:cli_tools/better_command_runner.dart';
import 'package:config/config.dart';

import 'completion_script_carapace.dart';
import 'completion_script_completely.dart';

/// Example of using [BetterCommandRunner] with command line completion.
///
/// Run this example program like so:
/// ```sh
/// dart example/command_completion_example.dart completion install -t completely
/// ```
/// or
/// ```sh
/// dart example/command_completion_example.dart completion install -t carapace
/// source <(carapace example) # for bash, for others see https://carapace.sh/setup.html
/// ```
///
/// In order to regenerate the completion scripts, run these commands for each
/// tool to target.
///
/// See also [README_completion.md].
///
/// Completely:
/// ```sh
/// dart example/command_completion_example.dart completion generate -t completely | completely generate - example.bash
/// dart example/command_completion_example.dart completion embed -t completely -f example.bash -d example/
/// ```
///
/// Carapace:
/// ```sh
/// dart example/command_completion_example.dart completion generate -t carapace -f example.yaml
/// dart example/command_completion_example.dart completion embed -t carapace -f example.yaml -d example/
/// ```
Future<void> main(final List<String> args) async {
  final commandRunner = BetterCommandRunner(
    'example',
    'Example CLI command',
    enableCompletionCommand: true,
    embeddedCompletions: [
      completionScriptCompletely,
      completionScriptCarapace,
    ],
  );

  try {
    await commandRunner.run(args);
  } on UsageException catch (e) {
    print(e);
    exitCode = 1;
  }
}
