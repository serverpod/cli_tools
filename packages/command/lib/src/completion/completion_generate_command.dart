import 'dart:io' show IOSink, stdout, stderr;

import 'package:config/config.dart';

import '../command.dart';
import '../command_runner.dart' show StandardGlobalOption;
import 'carapace_generator.dart';
import 'completely_generator.dart';
import 'completion_command.dart' show CompletionOptions;
import 'completion_tool.dart';
import 'usage_representation.dart';

enum CompletionGenerateOption<V extends Object> implements OptionDefinition<V> {
  tool(CompletionOptions.toolOption),
  execName(CompletionOptions.execNameOption),
  file(
    FileOption(
      argName: 'file',
      argAbbrev: 'f',
      helpText: 'Write the specification to a file instead of stdout',
    ),
  )
  ;

  const CompletionGenerateOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

class CompletionGenerateCommand<T>
    extends NewCommand<CompletionGenerateOption, T> {
  CompletionGenerateCommand() : super(options: CompletionGenerateOption.values);

  @override
  String get name => 'generate';

  @override
  String get description => 'Generate a command line completion specification';

  @override
  Future<T> run(RunContext<CompletionGenerateOption> runContext) async {
    final commandConfig = runContext.commandConfig;
    final tool = commandConfig.value(CompletionGenerateOption.tool);
    final execName = commandConfig.optionalValue(
      CompletionGenerateOption.execName,
    );
    final file = commandConfig.optionalValue(CompletionGenerateOption.file);

    final cmdRunner = runner;
    if (cmdRunner == null) {
      throw StateError('NewCommandRunner not set');
    }

    final usage = UsageRepresentation.compile(
      cmdRunner,
      execNameOverride: execName,
    );

    final IOSink out = file?.openWrite() ?? stdout;

    switch (tool) {
      case CompletionTool.completely:
        CompletelyYamlGenerator().generate(out, usage);
        break;
      case CompletionTool.carapace:
        CarapaceYamlGenerator().generate(out, usage);
        break;
    }

    if (file != null) {
      await out.flush();
      await out.close();
    }

    if (runContext.globalConfig.findValueOf(
          argName: StandardGlobalOption.verbose.option.argName,
        ) ==
        true) {
      final out = file == null ? ' to stdout' : ': ${file.path}';
      stderr.writeln('Generated specification$out');
    }
    return null as T;
  }
}
