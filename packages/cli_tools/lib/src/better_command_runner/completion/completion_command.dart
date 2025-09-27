import 'dart:async';

import 'package:config/config.dart';

import '../better_command.dart';
import 'completion_embed_command.dart';
import 'completion_generate_command.dart';
import 'completion_install_command.dart';
import 'completion_target.dart';

abstract final class CompletionOptions {
  static const targetOption = EnumOption(
    enumParser: EnumParser(CompletionTarget.values),
    argName: 'target',
    argAbbrev: 't',
    helpText: 'The target tool format',
    mandatory: true,
  );
  static const execNameOption = StringOption(
    argName: 'exec-name',
    argAbbrev: 'e',
    helpText: 'Override the name of the executable',
  );
}

class CompletionCommand<T> extends BetterCommand<OptionDefinition, T> {
  CompletionCommand({
    final Iterable<CompletionScript>? embeddedCompletions,
  }) {
    addSubcommand(CompletionGenerateCommand());
    addSubcommand(CompletionEmbedCommand());
    if (embeddedCompletions != null) {
      addSubcommand(CompletionInstallCommand(
        embeddedCompletions: embeddedCompletions,
      ));
    }
  }

  @override
  String get name => 'completion';

  @override
  String get description => 'Command line completion commands';

  @override
  FutureOr<T>? runWithConfig(final Configuration commandConfig) {
    return null;
  }
}
