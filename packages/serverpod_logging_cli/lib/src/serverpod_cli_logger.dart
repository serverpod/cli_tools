import 'dart:async';
import 'dart:io';

import 'package:cli_tools/cli_tools.dart' as cli;
import 'package:serverpod_logging/serverpod_logging.dart';

import 'std_out_log_writer.dart';

/// A [cli.Logger] that delegates to a [Log].
///
/// This bridges the [cli.Logger] interface with the [LogWriter] architecture,
/// allowing multi-backend logging (terminal, TUI, file, database, etc.) via
/// [LogWriter] and [MultiLogWriter].
///
/// [cli.LogType] is preserved by stashing it in [LogEntry.metadata] under
/// [logTypeKey], so writers like [StdOutLogWriter] can format accordingly.
class ServerpodCliLogger extends cli.Logger {
  final Log _log;
  final LogWriter _writer;

  ServerpodCliLogger(LogWriter writer, {LogLevel logLevel = LogLevel.info})
    : _writer = writer,
      _log = Log(writer, logLevel: logLevel),
      super(toCliLogLevel(logLevel));

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
  }) => _call(LogLevel.debug, message, type: type);

  @override
  void info(
    String message, {
    bool newParagraph = false,
    cli.LogType type = cli.TextLogType.normal,
  }) => _call(LogLevel.info, message, type: type);

  @override
  void warning(
    String message, {
    bool newParagraph = false,
    cli.LogType type = cli.TextLogType.normal,
  }) => _call(LogLevel.warning, message, type: type);

  @override
  void error(
    String message, {
    bool newParagraph = false,
    StackTrace? stackTrace,
    cli.LogType type = cli.TextLogType.normal,
  }) => _call(LogLevel.error, message, stackTrace: stackTrace, type: type);

  @override
  void log(
    String message,
    cli.LogLevel level, {
    bool newParagraph = false,
    cli.LogType type = cli.TextLogType.normal,
  }) {
    // `nothing` is the "off" sentinel, not a message level - suppress rather
    // than map it (mapping would throw on this otherwise-valid enum value).
    if (level == cli.LogLevel.nothing) return;
    _call(_mapLogLevel(level), message, type: type);
  }

  @override
  void write(
    String message,
    cli.LogLevel logLevel, {
    bool newParagraph = false,
    bool newLine = true,
  }) {
    if (logLevel == cli.LogLevel.nothing) return;
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

  /// Renders [stream] as a parent operation with one nested sub-operation per
  /// event. Each sub-operation stays open until the next event arrives (or the
  /// stream ends), so its elapsed time is the gap between events. The parent
  /// closes when the stream completes.
  ///
  /// Returns the last event. Rethrows a stream error (failing the open
  /// sub-operation and the parent). Throws [StateError] if the stream is empty.
  @override
  Future<T> progressStream<T>(
    String initialMessage,
    Stream<T> stream, {
    String Function(T)? toMessage,
    bool Function(T)? isSuccess,
    bool newParagraph = false,
  }) async {
    if (_silent) return _drain(stream);

    T? last;
    return _log.progress<T>(
      initialMessage,
      () async {
        final events = StreamIterator(stream);
        try {
          if (!await events.moveNext()) {
            throw StateError(_noEventsMessage);
          }
          while (true) {
            final event = events.current;
            last = event;
            final label = toMessage?.call(event) ?? event.toString();
            // The sub-operation's lifetime is the wait for the next event.
            var hasMore = false;
            await _log.progress<bool>(label, () async {
              hasMore = await events.moveNext();
              return true;
            });
            if (!hasMore) break;
          }
        } finally {
          await events.cancel();
        }
        return last as T;
      },
      // Let Log own the success verdict
      isSuccess: isSuccess ?? (_) => true,
    );
  }

  @override
  Future<void> flush() => _log.flush();

  /// Consumes [stream] without rendering, honoring the same return/throw
  /// contract as [progressStream] (used when output is silenced).
  static Future<T> _drain<T>(Stream<T> stream) async {
    T? last;
    var hasEvent = false;
    await for (final event in stream) {
      hasEvent = true;
      last = event;
    }
    if (!hasEvent) throw StateError(_noEventsMessage);
    return last as T;
  }

  static const _noEventsMessage = 'No events in stream';

  void _call(
    LogLevel level,
    String message, {
    StackTrace? stackTrace,
    cli.LogType? type,
  }) {
    if (_silent) return;
    _log(
      level,
      () => LogEntry(
        time: DateTime.now(),
        level: level,
        message: message,
        scope: _log.currentScope,
        stackTrace: stackTrace,
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
