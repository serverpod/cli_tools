import 'dart:io' show IOSink, stdout;

import 'package:config/config.dart';

import '../better_command.dart';
import 'carapace_generator.dart';
import 'completely_generator.dart';
import 'completion_command.dart' show CompletionOptions;
import 'completion_target.dart';
import 'usage_representation.dart';

enum CompletionGenerateOption<V extends Object> implements OptionDefinition<V> {
  target(CompletionOptions.targetOption),
  execName(CompletionOptions.execNameOption),
  file(FileOption(
    argName: 'file',
    argAbbrev: 'f',
    helpText: 'Write the specification to a file instead of stdout',
  ));

  const CompletionGenerateOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

class CompletionGenerateCommand<T>
    extends BetterCommand<CompletionGenerateOption, T> {
  CompletionGenerateCommand() : super(options: CompletionGenerateOption.values);

  @override
  String get name => 'generate';

  @override
  String get description => 'Generate a command line completion specification';

  @override
  Future<T> runWithConfig(
      final Configuration<CompletionGenerateOption> commandConfig) async {
    final target = commandConfig.value(CompletionGenerateOption.target);
    final execName =
        commandConfig.optionalValue(CompletionGenerateOption.execName);
    final file = commandConfig.optionalValue(CompletionGenerateOption.file);

    final betterRunner = runner;
    if (betterRunner == null) {
      throw Exception('BetterCommandRunner not set in the completion command');
    }

    final usage = UsageRepresentation.compile(
      betterRunner,
      execNameOverride: execName,
    );

    final IOSink out = file?.openWrite() ?? stdout;

    switch (target) {
      case CompletionTarget.completely:
        CompletelyYamlGenerator().generate(out, usage);
        break;
      case CompletionTarget.carapace:
        CarapaceYamlGenerator().generate(out, usage);
        break;
    }

    if (file != null) {
      await out.flush();
      await out.close();
    }
    return null as T;
  }
}
