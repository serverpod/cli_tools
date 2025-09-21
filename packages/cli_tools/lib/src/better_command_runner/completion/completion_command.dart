import 'dart:io' show IOSink, stdout;

import 'package:config/config.dart';

import '../better_command.dart';
import 'completely_generator.dart';
import 'usage_representation.dart';

enum CompletionTarget {
  completely,
}

enum CompletionOption<V extends Object> implements OptionDefinition<V> {
  target(EnumOption(
    enumParser: EnumParser(CompletionTarget.values),
    argName: 'target',
    argAbbrev: 't',
    defaultsTo: CompletionTarget.completely,
  )),
  execName(StringOption(
    argName: 'exec-name',
    argAbbrev: 'e',
    helpText: 'Override the name of the executable',
  )),
  file(FileOption(
    argName: 'file',
    argAbbrev: 'f',
    helpText: 'Write the specification to a file instead of stdout',
  ));

  const CompletionOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

class CompletionCommand<T> extends BetterCommand<CompletionOption, T> {
  CompletionCommand() : super(options: CompletionOption.values);

  @override
  String get name => 'completion';

  @override
  String get description => 'Generate a command line completion specification';

  @override
  Future<T> runWithConfig(
      final Configuration<CompletionOption> commandConfig) async {
    final target = commandConfig.value(CompletionOption.target);
    final execName = commandConfig.optionalValue(CompletionOption.execName);
    final file = commandConfig.optionalValue(CompletionOption.file);

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
    }

    if (file != null) {
      await out.flush();
      await out.close();
    }
    return null as T;
  }
}
