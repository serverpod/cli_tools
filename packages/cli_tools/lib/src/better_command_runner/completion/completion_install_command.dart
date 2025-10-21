import 'dart:io' show Platform, File, stderr, Directory;

import 'package:config/config.dart';
import 'package:path/path.dart' as p;

import '../better_command.dart';
import '../better_command_runner.dart' show StandardGlobalOption;
import '../exit_exception.dart';
import 'completion_command.dart' show CompletionOptions;
import 'completion_tool.dart';

enum CompletionInstallOption<V extends Object> implements OptionDefinition<V> {
  tool(CompletionOptions.toolOption),
  execName(CompletionOptions.execNameOption),
  writeDir(DirOption(
    argName: 'write-dir',
    argAbbrev: 'd',
    helpText: 'Override the directory to write the script to',
    mode: PathExistMode.mustExist,
  ));

  const CompletionInstallOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

class CompletionInstallCommand<T>
    extends BetterCommand<CompletionInstallOption, T> {
  final Map<CompletionTool, String> _embeddedCompletions;

  CompletionInstallCommand({
    required final Iterable<CompletionScript> embeddedCompletions,
  })  : _embeddedCompletions = Map.fromEntries(embeddedCompletions.map(
          (final e) => MapEntry(e.tool, e.script),
        )),
        super(options: CompletionInstallOption.values);

  @override
  String get name => 'install';

  @override
  String get description => 'Install a command line completion script';

  @override
  Future<T> runWithConfig(
      final Configuration<CompletionInstallOption> commandConfig) async {
    final tool = commandConfig.value(CompletionInstallOption.tool);
    final execName =
        commandConfig.optionalValue(CompletionInstallOption.execName);
    final writeDir =
        commandConfig.optionalValue(CompletionInstallOption.writeDir);

    final betterRunner = runner;
    if (betterRunner == null) {
      throw StateError('BetterCommandRunner not set');
    }

    final scriptContent = _embeddedCompletions[tool];
    if (scriptContent == null) {
      stderr.writeln('No embedded script found for tool "$tool"');
      throw ExitException.error();
    }

    final executableName = execName ?? betterRunner.executableName;

    final writeFileName = switch (tool) {
      CompletionTool.completely => '$executableName.bash',
      CompletionTool.carapace => '$executableName.yaml',
    };
    final writeDirPath = writeDir?.path ??
        switch (tool) {
          CompletionTool.completely => p.join(
              _getHomeDir(),
              '.local',
              'share',
              'bash-completion',
              'completions',
            ),
          CompletionTool.carapace => p.join(
              _getUserConfigDir(),
              'carapace',
              'specs',
            ),
        };
    final writeFilePath = p.join(writeDirPath, writeFileName);

    await Directory(writeDirPath).create(recursive: true);
    final out = File(writeFilePath).openWrite();
    out.write(scriptContent);
    await out.flush();
    await out.close();

    if (betterRunner.globalConfiguration.findValueOf(
            argName: StandardGlobalOption.verbose.option.argName) ==
        true) {
      stderr.writeln('Installed script: $writeFilePath');
    }
    return null as T;
  }

  /// Returns the user configuration directory for the current platform.
  /// See also: https://specifications.freedesktop.org/basedir-spec/
  static String _getUserConfigDir() {
    if (Platform.environment['XDG_CONFIG_HOME'] case final String configHome) {
      return configHome;
    }
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return appData;
      }
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        return p.join(userProfile, 'AppData', 'Roaming');
      }
      throw Exception('APPDATA environment variable is not set');
    } else if (Platform.isMacOS) {
      return '${_getHomeDir()}/Library/Application Support';
    } else if (Platform.isLinux) {
      return '${_getHomeDir()}/.config';
    }
    throw Exception('Unsupported platform: ${Platform.operatingSystem}');
  }

  static String _getHomeDir() {
    final homeDir = Platform.environment['HOME'];
    if (homeDir == null) {
      throw Exception('HOME environment variable is not set');
    }
    return homeDir;
  }
}
