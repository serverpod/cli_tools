import 'dart:convert' show Utf8Decoder, Utf8Encoder;
import 'dart:io'
    show Directory, File, FileMode, FileSystemException, Platform, Process;
import 'dart:typed_data' show ByteData, Endian, Uint8List;

import 'package:path/path.dart' as p;

import 'completion_shell.dart';

/// A step of a completion installation: a change to the file system,
/// or a note that a file needs no change.
class CompletionInstallStep {
  /// What the step does, as printed by `completion install`.
  /// A change to the content of a file has the added lines on the lines
  /// that follow the first one.
  final String description;

  final void Function() _perform;

  CompletionInstallStep(this.description, this._perform);

  /// Makes the change described by [description].
  void perform() => _perform();
}

/// Installs the completion script of a shell for the current user,
/// in the way that is the common practice for the shell:
///
/// - Bash: the script is saved in the user directory of bash-completion,
///   which loads it on demand. Since bash-completion may not be installed,
///   the script is also sourced from `~/.bashrc`. On macOS, where terminals
///   start login shells, it is sourced from `~/.bash_profile` instead (or
///   from `~/.bash_login` or `~/.profile` if that is the file in use).
/// - Zsh: the script is saved as an autoloadable `_name` function file and
///   sourced from `.zshrc`, after initializing the completion system
///   (`compinit`) unless the startup file has already done so.
/// - Fish: the script is saved in the Fish user completions directory,
///   from where Fish loads it on demand.
/// - PowerShell: the script is saved next to the PowerShell profile
///   (`$PROFILE`) and loaded from it.
/// - Carapace: the spec is saved in the Carapace user specs directory.
///
/// The XDG base directories are honored where the shell honors them.
/// An installation can be repeated: the script is overwritten, and a
/// startup file that already loads it is left as it is.
///
/// A startup file is read and appended to in its own encoding: UTF-16 or
/// UTF-32 if it starts with the byte order mark of that encoding (as a
/// profile written by Windows PowerShell does), otherwise UTF-8.
class CompletionInstaller {
  /// The environment variables that determine the installation locations.
  final Map<String, String> environment;

  /// The operating system to install for, as in [Platform.operatingSystem].
  final String operatingSystem;

  final String? Function() _queryPowerShellProfile;

  final p.Context _path;

  /// [environment] and [operatingSystem] default to those of the process.
  ///
  /// [powerShellProfile] returns the path of the PowerShell profile on
  /// Windows, or null if unknown. By default PowerShell is asked for it,
  /// since the location depends on the PowerShell edition and on where the
  /// user's documents folder is. Elsewhere the path follows from the
  /// environment.
  CompletionInstaller({
    final Map<String, String>? environment,
    final String? operatingSystem,
    final String? Function()? powerShellProfile,
  }) : this._(
         environment ?? Platform.environment,
         operatingSystem ?? Platform.operatingSystem,
         powerShellProfile ?? _askPowerShellForProfile,
       );

  CompletionInstaller._(
    this.environment,
    this.operatingSystem,
    this._queryPowerShellProfile,
  ) : _path = p.Context(
        style: operatingSystem == 'windows' ? p.Style.windows : p.Style.posix,
      );

  bool get _isWindows => operatingSystem == 'windows';

  bool get _isMacOS => operatingSystem == 'macos';

  /// Whether a completion can be installed for the command [name].
  ///
  /// The script is saved in a file named after the command, which is how
  /// the shells find it. The name must therefore be the name of the command
  /// as a file name, not a path to it: not empty, `.` or `..`, and without
  /// path separators (`/` and `\`) and control characters.
  static bool isCommandName(final String name) {
    return name.isNotEmpty &&
        name != '.' &&
        name != '..' &&
        !_notInCommandName.hasMatch(name);
  }

  static final _notInCommandName = RegExp(r'[/\\\x00-\x1f\x7f]');

  static void _checkCommandName(final String name) {
    if (isCommandName(name)) return;
    throw ArgumentError.value(
      name,
      'name',
      'Not a command name to install a completion for: '
          'it must be a file name without a directory',
    );
  }

  /// Plans the installation of [script], the completion script of [shell]
  /// for the command [name], and returns its steps in order.
  ///
  /// Nothing is changed until the steps are performed. The steps are
  /// planned from the current state of the file system: directories that
  /// exist are not created, and a startup file that already loads the
  /// script is not changed.
  ///
  /// [executableName] is named in the startup file as the origin of the
  /// lines added to it.
  ///
  /// Throws an [ArgumentError] if [name] is not a command name, see
  /// [isCommandName], and a [FileSystemException] if the user's home
  /// directory is unknown.
  List<CompletionInstallStep> plan(
    final CompletionShell shell, {
    required final String name,
    required final String script,
    required final String executableName,
  }) {
    final scriptFile = scriptPath(shell, name);
    final startupFile = startupFilePath(shell);
    final plannedDirectories = <String>{};
    return [
      ..._createDirectory(_path.dirname(scriptFile), plannedDirectories),
      CompletionInstallStep(
        'Write $scriptFile',
        () => File(scriptFile).writeAsStringSync(script),
      ),
      if (startupFile != null)
        ..._addToStartupFile(startupFile, [
          '# $name shell completion, '
              'added by `$executableName completion install`.',
          ..._loadLines(shell, scriptFile),
        ], plannedDirectories),
    ];
  }

  /// The file that the completion script of [shell] for the command [name]
  /// is installed as.
  ///
  /// Throws an [ArgumentError] if [name] is not a command name, see
  /// [isCommandName]: as a path it would name a file elsewhere.
  String scriptPath(final CompletionShell shell, final String name) {
    _checkCommandName(name);
    return switch (shell) {
      CompletionShell.bash => _path.join(
        environment.valueOf('BASH_COMPLETION_USER_DIR') ??
            _path.join(_dataHome, 'bash-completion'),
        'completions',
        name,
      ),
      CompletionShell.zsh => _path.join(
        _dataHome,
        'zsh',
        'site-functions',
        '_$name',
      ),
      CompletionShell.fish => _path.join(
        _configHome,
        'fish',
        'completions',
        '$name.fish',
      ),
      CompletionShell.powershell => _path.join(
        _path.dirname(_powerShellProfile),
        'Completions',
        '$name.ps1',
      ),
      CompletionShell.carapace => _path.join(
        _carapaceConfigDir,
        'carapace',
        'specs',
        '$name.yaml',
      ),
    };
  }

  /// The shell startup file that loads the installed script of [shell],
  /// or null if the shell finds the script by itself.
  String? startupFilePath(final CompletionShell shell) {
    return switch (shell) {
      CompletionShell.bash => _bashStartupFile,
      CompletionShell.zsh => _path.join(
        environment.valueOf('ZDOTDIR') ?? _home,
        '.zshrc',
      ),
      CompletionShell.powershell => _powerShellProfile,
      CompletionShell.fish || CompletionShell.carapace => null,
    };
  }

  /// The lines of the startup file of [shell] that load [scriptFile].
  /// The last one is the line that names the file.
  List<String> _loadLines(
    final CompletionShell shell,
    final String scriptFile,
  ) {
    final file = shell == CompletionShell.powershell
        ? "'${scriptFile.replaceAll("'", "''")}'"
        : shellQuote(scriptFile);
    return switch (shell) {
      CompletionShell.bash => ['[ -r $file ] && source $file'],
      CompletionShell.zsh => [
        r'(( $+functions[compdef] )) || { autoload -Uz compinit && compinit; }',
        '[[ -r $file ]] && source $file',
      ],
      CompletionShell.powershell => [
        'if (Test-Path -LiteralPath $file) { . $file }',
      ],
      CompletionShell.fish || CompletionShell.carapace => const [],
    };
  }

  List<CompletionInstallStep> _createDirectory(
    final String directory,
    final Set<String> plannedDirectories,
  ) {
    final isPlanned = plannedDirectories.any(
      (final planned) =>
          planned == directory || _path.isWithin(directory, planned),
    );
    if (isPlanned || Directory(directory).existsSync()) return const [];
    plannedDirectories.add(directory);
    return [
      CompletionInstallStep(
        'Create directory $directory',
        () => Directory(directory).createSync(recursive: true),
      ),
    ];
  }

  /// Appends [lines] to the startup file at [path],
  /// unless it contains the last line already.
  ///
  /// An existing file is read and appended to in its own encoding.
  List<CompletionInstallStep> _addToStartupFile(
    final String path,
    final List<String> lines,
    final Set<String> plannedDirectories,
  ) {
    final file = File(path);
    final bytes = file.existsSync() ? file.readAsBytesSync() : null;
    final encoding = bytes == null
        ? _TextEncoding.utf8
        : _TextEncoding.of(bytes);
    final content = bytes == null ? null : encoding.decode(bytes);
    if (content != null && content.contains(lines.last)) {
      return [
        CompletionInstallStep('Keep $path, it already loads the script', () {}),
      ];
    }

    // Start on a new line, after an empty line.
    final separator = content == null || content.isEmpty
        ? ''
        : content.endsWith('\n')
        ? '\n'
        : '\n\n';
    return [
      ..._createDirectory(_path.dirname(path), plannedDirectories),
      CompletionInstallStep(
        [
          '${content == null ? 'Create' : 'Append to'} $path:',
          for (final line in lines) '  $line',
        ].join('\n'),
        () => file.writeAsBytesSync(
          encoding.encode('$separator${lines.join('\n')}\n'),
          mode: FileMode.append,
        ),
      ),
    ];
  }

  String get _home {
    final home =
        environment.valueOf('HOME') ??
        (_isWindows ? environment.valueOf('USERPROFILE') : null);
    if (home != null) return home;
    throw FileSystemException(
      'Cannot determine the home directory: the environment variable '
      '${_isWindows ? 'USERPROFILE' : 'HOME'} is not set',
    );
  }

  String get _dataHome =>
      environment.valueOf('XDG_DATA_HOME') ??
      _path.join(_home, '.local', 'share');

  String get _configHome =>
      environment.valueOf('XDG_CONFIG_HOME') ?? _path.join(_home, '.config');

  /// The user configuration directory as Carapace determines it:
  /// that of the XDG base directories if set, else that of the platform.
  String get _carapaceConfigDir {
    final xdgConfigHome = environment.valueOf('XDG_CONFIG_HOME');
    if (xdgConfigHome != null) return xdgConfigHome;
    if (_isWindows) {
      return environment.valueOf('APPDATA') ??
          _path.join(_home, 'AppData', 'Roaming');
    }
    if (_isMacOS) return _path.join(_home, 'Library', 'Application Support');
    return _path.join(_home, '.config');
  }

  /// `~/.bashrc`, which is read by interactive shells that are not login
  /// shells. On macOS, the file that login shells read instead: the first
  /// of the candidates that exists is the only one Bash reads.
  String get _bashStartupFile {
    if (!_isMacOS) return _path.join(_home, '.bashrc');
    final candidates = [
      for (final name in const ['.bash_profile', '.bash_login', '.profile'])
        _path.join(_home, name),
    ];
    return candidates.firstWhere(
      (final candidate) => File(candidate).existsSync(),
      orElse: () => candidates.first,
    );
  }

  late final String _powerShellProfile = _findPowerShellProfile();

  String _findPowerShellProfile() {
    const profile = 'Microsoft.PowerShell_profile.ps1';
    if (!_isWindows) return _path.join(_configHome, 'powershell', profile);
    return _queryPowerShellProfile() ??
        _path.join(_home, 'Documents', 'PowerShell', profile);
  }
}

/// Asks PowerShell for the path of the profile of the current user.
/// Prefers PowerShell 7+ (`pwsh`) to Windows PowerShell (`powershell`).
String? _askPowerShellForProfile() {
  for (final executable in const ['pwsh', 'powershell']) {
    try {
      final result = Process.runSync(executable, const [
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        r'$PROFILE',
      ]);
      final profile = (result.stdout as String).trim();
      if (result.exitCode == 0 && profile.isNotEmpty) return profile;
    } on Exception {
      // Not installed: try the next one.
    }
  }
  return null;
}

/// The text encoding of a startup file. The UTF-16 and UTF-32 encodings
/// are recognized by their byte order mark; a file without one is UTF-8.
enum _TextEncoding {
  utf8(1, Endian.little),
  utf16LittleEndian(2, Endian.little),
  utf16BigEndian(2, Endian.big),
  utf32LittleEndian(4, Endian.little),
  utf32BigEndian(4, Endian.big);

  /// The number of bytes of a code unit.
  final int _unitSize;

  /// The byte order of a code unit.
  final Endian _endian;

  const _TextEncoding(this._unitSize, this._endian);

  static const _byteOrderMark = 0xfeff;

  /// The encoding of the file content [bytes].
  static _TextEncoding of(final Uint8List bytes) {
    bool startsWith(final List<int> prefix) {
      if (bytes.length < prefix.length) return false;
      for (var i = 0; i < prefix.length; i++) {
        if (bytes[i] != prefix[i]) return false;
      }
      return true;
    }

    // The UTF-32 marks first: the little-endian one starts with the
    // little-endian mark of UTF-16.
    if (startsWith(const [0xff, 0xfe, 0x00, 0x00])) return utf32LittleEndian;
    if (startsWith(const [0x00, 0x00, 0xfe, 0xff])) return utf32BigEndian;
    if (startsWith(const [0xff, 0xfe])) return utf16LittleEndian;
    if (startsWith(const [0xfe, 0xff])) return utf16BigEndian;
    return utf8;
  }

  /// The text of the file content [bytes], without the byte order mark.
  /// Malformed content is decoded as far as possible.
  String decode(final Uint8List bytes) {
    if (this == utf8) {
      return const Utf8Decoder(allowMalformed: true).convert(bytes);
    }
    final data = ByteData.sublistView(bytes);
    final units = [
      for (var i = 0; i + _unitSize <= bytes.length; i += _unitSize)
        _unitSize == 2
            ? data.getUint16(i, _endian)
            : data.getUint32(i, _endian),
    ];
    if (units.isNotEmpty && units.first == _byteOrderMark) units.removeAt(0);
    if (_unitSize == 2) return String.fromCharCodes(units);
    return String.fromCharCodes([
      for (final unit in units) unit > 0x10ffff ? 0xfffd : unit,
    ]);
  }

  /// The bytes of [text] to append to a file with this encoding.
  List<int> encode(final String text) {
    if (this == utf8) return const Utf8Encoder().convert(text);
    final units = _unitSize == 2 ? text.codeUnits : text.runes.toList();
    final data = ByteData(units.length * _unitSize);
    for (var i = 0; i < units.length; i++) {
      if (_unitSize == 2) {
        data.setUint16(i * _unitSize, units[i], _endian);
      } else {
        data.setUint32(i * _unitSize, units[i], _endian);
      }
    }
    return data.buffer.asUint8List();
  }
}

extension on Map<String, String> {
  /// The value of the variable [name], or null if it is not set or empty.
  String? valueOf(final String name) {
    final value = this[name];
    return value == null || value.isEmpty ? null : value;
  }
}
