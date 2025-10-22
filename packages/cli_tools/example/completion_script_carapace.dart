/// This file is auto-generated.
library;

import 'package:cli_tools/better_command_runner.dart' show CompletionTool;

const String _completionScript = r'''
# yaml-language-server: $schema=https://carapace.sh/schemas/command.json
name: example
persistentFlags:
  -q, --quiet: "Suppress all cli output. Is overridden by  -v, --verbose."
  -v, --verbose: "Prints additional information useful for development. Overrides --q, --quiet."

commands:
  - name: completion

    commands:
      - name: generate
        flags:
          -t, --tool=!: "The completion tool to target"
          -e, --exec-name=: "Override the name of the executable"
          -f, --file=: "Write the specification to a file instead of stdout"
        completion:
          flag:
            tool: ["completely", "carapace"]
            file: ["$files"]

      - name: install
        flags:
          -t, --tool=!: "The completion tool to target"
          -e, --exec-name=: "Override the name of the executable"
          -d, --write-dir=: "Override the directory to write the script to"
        completion:
          flag:
            tool: ["completely", "carapace"]
            write-dir: ["$directories"]


''';

/// Embedded script for command line completion for `carapace`.
const completionScriptCarapace = (
  tool: CompletionTool.carapace,
  script: _completionScript,
);
