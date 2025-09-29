import 'dart:convert' show utf8;
import 'dart:io' show Platform, Directory, File, stdin, stderr, IOSink, stdout;

import 'package:config/config.dart';
import 'package:path/path.dart' as p;
import 'package:super_string/super_string.dart';

import '../better_command.dart';
import '../better_command_runner.dart' show StandardGlobalOption;
import 'completion_command.dart' show CompletionOptions;

enum CompletionEmbedOption<V extends Object> implements OptionDefinition<V> {
  target(CompletionOptions.targetOption),
  scriptFileName(StringOption(
    argName: 'script-file',
    argAbbrev: 'f',
    helpText: 'Read the script to embed from a file instead of stdin',
  )),
  outFileName(StringOption(
    argName: 'output-file',
    argAbbrev: 'o',
    helpText: 'The Dart file name to write ("-" for stdout)',
    fromCustom: _outputSourceFileName,
    customValidator: _validateSourceFileName,
    defaultsTo: 'completion_script_<target>.dart',
  )),
  outDir(DirOption(
    argName: 'output-dir',
    argAbbrev: 'd',
    helpText: 'Override the directory to write the Dart source file to',
    mode: PathExistMode.mustExist,
    fromDefault: _defaultWriteDir,
  ));

  const CompletionEmbedOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

/// Finds the package root directory above current script/executable containing
/// a pubspec.yaml. Returns null if no such directory is found.
Directory? _findPackageRoot() {
  final String scriptDir = Platform.script.resolve('.').toFilePath();

  Directory dir = Directory(scriptDir);
  while (dir.path != dir.parent.path) {
    if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
      return dir;
    }
    dir = dir.parent;
  }
  return null;
}

Directory _defaultWriteDir() {
  final dir = _findPackageRoot();
  if (dir == null) {
    return Directory.current;
  }
  return Directory(p.join(dir.path, 'lib', 'src'));
}

String _outputSourceFileName(final Configuration cfg) {
  final target = cfg.value(CompletionEmbedOption.target);
  return 'completion_script_${target.name}.dart';
}

void _validateSourceFileName(final String value) {
  if (value == '-') {
    return;
  }
  if (value.contains('/') || value.contains('\\')) {
    throw FormatException('Dart file name "$value" cannot contain a path');
  }
  if (!value.endsWith('.dart')) {
    throw FormatException('Dart file name "$value" does not end with ".dart"');
  }
}

class CompletionEmbedCommand<T>
    extends BetterCommand<CompletionEmbedOption, T> {
  CompletionEmbedCommand() : super(options: CompletionEmbedOption.values);

  @override
  String get name => 'embed';

  @override
  String get description =>
      'Embed a command line completion script in the command source code';

  @override
  bool get hidden => true;

  @override
  Future<T> runWithConfig(
      final Configuration<CompletionEmbedOption> commandConfig) async {
    final target = commandConfig.value(CompletionEmbedOption.target);
    final scriptFileName =
        commandConfig.optionalValue(CompletionEmbedOption.scriptFileName);
    final writeFile = commandConfig.value(CompletionEmbedOption.outFileName);
    final writeDir = commandConfig.value(CompletionEmbedOption.outDir);

    final String scriptContent;
    if (scriptFileName == null) {
      scriptContent = await stdin.transform(utf8.decoder).join();
    } else {
      final scriptFile = File(scriptFileName);
      scriptContent = scriptFile.readAsStringSync();
    }

    final outputContent = """
/// This file is auto-generated.
library;

import 'package:cli_tools/better_command_runner.dart' show CompletionTarget;

const String _completionScript = r'''
$scriptContent
''';

/// Embedded script for command line completion for `${target.name}`.
const completionScript${target.name.capitalize()} = (
  target: $target,
  script: _completionScript,
);
""";

    final File? embeddedFile =
        writeFile == '-' ? null : File(p.join(writeDir.path, writeFile));

    final IOSink out = embeddedFile?.openWrite() ?? stdout;

    out.write(outputContent);

    if (embeddedFile != null) {
      await out.flush();
      await out.close();
    }

    if (runner?.globalConfiguration.findValueOf(
            argName: StandardGlobalOption.verbose.option.argName) ==
        true) {
      final out =
          embeddedFile == null ? ' to stdout' : ': ${embeddedFile.path}';
      stderr.writeln('Wrote embedded script$out');
    }

    return null as T;
  }
}
