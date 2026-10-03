import 'dart:async';

import 'package:config/config.dart';

import '../command.dart';
import 'completion_embed_command.dart';
import 'completion_generate_command.dart';
import 'completion_install_command.dart';
import 'completion_tool.dart';

abstract final class CompletionOptions {
  static const toolOption = EnumOption(
    enumParser: EnumParser(CompletionTool.values),
    argName: 'tool',
    argAbbrev: 't',
    helpText: 'The completion tool to target',
    allowedHelp: {
      'completely':
          'Use the `completely` tool (https://github.com/bashly-framework/completely)',
      'carapace': 'Use the `carapace` tool (https://carapace.sh/)',
    },
    mandatory: true,
  );
  static const execNameOption = StringOption(
    argName: 'exec-name',
    argAbbrev: 'e',
    helpText: 'Override the name of the executable',
  );
}

class CompletionCommand<T> extends NewCommand<OptionDefinition, T> {
  CompletionCommand({
    Iterable<CompletionScript>? embeddedCompletions,
  }) {
    addSubcommand(CompletionGenerateCommand());
    addSubcommand(CompletionEmbedCommand());
    if (embeddedCompletions != null) {
      addSubcommand(
        CompletionInstallCommand(
          embeddedCompletions: embeddedCompletions,
        ),
      );
    }
  }

  @override
  String get name => 'completion';

  @override
  String get description => 'Command line completion commands';

  @override
  FutureOr<T>? run(RunContext runContext) {
    return null;
  }
}
