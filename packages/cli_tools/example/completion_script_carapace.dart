/// This file is auto-generated.
library;

import 'package:cli_tools/better_command_runner.dart' show CompletionTarget;

const String _completionScript = r'''
# yaml-language-server: $schema=https://carapace.sh/schemas/command.json
name: example
persistentFlags:
  -q, --quiet: Suppress all cli output. Is overridden by  -v, --verbose.
  -v, --verbose: Prints additional information useful for development. Overrides --q, --quiet.

commands:
  - name: completion

    commands:
      - name: generate
        flags:
          -t, --target=!: The target tool format
          -e, --exec-name=: Override the name of the executable
          -f, --file=: Write the specification to a file instead of stdout
        completion:
          flag:
            target: ["completely", "carapace"]
            file: ["$files"]

      - name: embed
        flags:
          -t, --target=!: The target tool format
          -f, --script-file=: The script file to embed
          -o, --output-file=: The Dart file name to write
          -d, --output-dir=: Override the directory to write the Dart source file to
        completion:
          flag:
            target: ["completely", "carapace"]
            output-dir: ["$directories"]

      - name: install
        flags:
          -t, --target=!: The target tool format
          -e, --exec-name=: Override the name of the executable
          -d, --write-dir=: Override the directory to write the script to
        completion:
          flag:
            target: ["completely", "carapace"]
            write-dir: ["$directories"]

  - name: install
    flags:
      -t, --target=!: The target tool format
      -e, --exec-name=: Override the name of the executable
      -d, --write-dir=: Override the directory to write the script to
    completion:
      flag:
        target: ["completely", "carapace"]
        write-dir: ["$directories"]


''';

/// Embedded script for command line completion for `carapace`.
const completionScriptCarapace = (
  target: CompletionTarget.carapace,
  script: _completionScript,
);
