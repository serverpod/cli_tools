import 'dart:io';

import 'package:cli_tools/cli_tools.dart' as cli;

import 'log.dart';
import 'log_types.dart';
import 'std_out_log_writer.dart';

// ---------------------------------------------------------------------------
// ServerpodCliLogger - bridges cli_tools.Logger to the serverpod_logging Log
// ---------------------------------------------------------------------------

/// A [cli.Logger] that delegates to a serverpod_logging [Log].
///
/// This bridges the cli_tools logging interface with the serverpod_logging
/// log writer architecture, allowing multi-backend logging (terminal, TUI,
/// file, etc.) via [LogWriter] and [MultiLogWriter].
///
/// [cli.LogType] is preserved by stashing it in [LogEntry.metadata]
/// under [logTypeKey], so writers like [StdOutLogWriter] can format
/// output accordingly.
class ServerpodCliLogger extends cli.Logger {
  final Log _log;
  final LogWriter _writer;

  ServerpodCliLogger(LogWriter writer, {LogLevel logLevel = LogLevel.info})
    : _writer = writer,
      _log = Log(writer, logLevel: logLevel),
      super(_mapLevel(logLevel));

  /// Releases any resources held by the underlying writer.
  Future<void> close() async {
    await _log.close();
    await _writer.close();
  }

  @override
  set logLevel(cli.LogLevel level) {
    super.logLevel = level;
    if (level == cli.LogLevel.nothing) return;
    _log.logLevel = _mapLogLevel(level);
  }

  @override
  int? get wrapTextColumn => stdout.hasTerminal ? stdout.terminalColumns : null;

  @override
  void debug(
    String message, {
    bool newParagraph = false,
    cli.LogType type = cli.TextLogType.normal,
  }) {
    _call(LogLevel.debug, message, type: type);
  }

  @override
  void info(
    String message, {
    bool newParagraph = false,
    cli.LogType type = cli.TextLogType.normal,
  }) {
    _call(LogLevel.info, message, type: type);
  }

  @override
  void warning(
    String message, {
    bool newParagraph = false,
    cli.LogType type = cli.TextLogType.normal,
  }) {
    _call(LogLevel.warning, message, type: type);
  }

  @override
  void error(
    String message, {
    bool newParagraph = false,
    StackTrace? stackTrace,
    cli.LogType type = cli.TextLogType.normal,
  }) {
    final msg = stackTrace != null
        ? '$message\n${stackTrace.toString()}'
        : message;
    _call(LogLevel.error, msg, type: type);
  }

  @override
  void log(
    String message,
    cli.LogLevel level, {
    bool newParagraph = false,
    cli.LogType type = cli.TextLogType.normal,
  }) {
    _call(_mapLogLevel(level), message, type: type);
  }

  @override
  void write(
    String message,
    cli.LogLevel logLevel, {
    bool newParagraph = false,
    bool newLine = true,
  }) {
    _call(_mapLogLevel(logLevel), message);
  }

  @override
  Future<bool> progress(
    String message,
    Future<bool> Function() runner, {
    bool newParagraph = false,
    String? successMessage,
  }) {
    if (_silent) return runner();
    return _log.progress(message, runner);
  }

  @override
  Future<T> progressStream<T>(
    String initialMessage,
    Stream<T> stream, {
    String Function(T)? toMessage,
    bool Function(T)? isSuccess,
    bool newParagraph = false,
  }) async {
    if (_silent) return stream.last;
    return _log.progressStream(
      initialMessage,
      stream,
      toMessage: toMessage,
      isSuccess: isSuccess,
    );
  }

  @override
  Future<void> flush() => _log.flush();

  void _call(LogLevel level, String message, {cli.LogType? type}) {
    if (_silent) return;
    _log(
      level,
      () => LogEntry(
        time: DateTime.now(),
        level: level,
        message: message,
        scope: _log.currentScope,
        metadata: type != null ? {logTypeKey: type} : null,
      ),
    );
  }

  // serverpod_logging LogLevel has no "nothing" sentinel - its lowest-passing
  // level is fatal, and the filter check is strict-`<` so fatal still leaks
  // through. Progress / scope events bypass logLevel entirely. So when the
  // caller sets cli.LogLevel.nothing we gate at the bridge instead of mapping
  // through to _log.logLevel.
  bool get _silent => super.logLevel == cli.LogLevel.nothing;

  static cli.LogLevel _mapLevel(LogLevel level) => switch (level) {
    LogLevel.debug => cli.LogLevel.debug,
    LogLevel.info => cli.LogLevel.info,
    LogLevel.warning => cli.LogLevel.warning,
    LogLevel.error || LogLevel.fatal => cli.LogLevel.error,
  };

  static LogLevel _mapLogLevel(cli.LogLevel level) => switch (level) {
    cli.LogLevel.debug => LogLevel.debug,
    cli.LogLevel.info => LogLevel.info,
    cli.LogLevel.warning => LogLevel.warning,
    cli.LogLevel.error => LogLevel.error,
    // The setter early-returns before reaching here, so this branch only
    // fires from log() / write() being called with nothing as a message
    // level - which is a programmer error worth surfacing.
    cli.LogLevel.nothing => throw ArgumentError.value(
      level,
      'level',
      'cli.LogLevel.nothing is a filter sentinel; it cannot be used as a '
          'message level',
    ),
  };
}
