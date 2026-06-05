import 'dart:async';

import 'log_types.dart';

/// Symbol used to store the current [LogScope] in Zone values.
const Symbol _logScopeKey = #_logScope;

/// Symbol used to store the current [LogWriter] in Zone values.
const Symbol _logWriterKey = #_logWriter;

final _stopwatch = Stopwatch()..start();
int _scopeCounter = 0;
String _newScopeId(String label) =>
    '${label.hashCode}_${_stopwatch.elapsedTicks}_${++_scopeCounter}';

/// A factory function that creates a [LogEntry].
typedef LogEntryFactory = FutureOr<LogEntry> Function();

/// A logger that delegates to a [LogWriter] and resolves the current
/// [LogScope] from the Zone.
///
/// Each call appends onto a rolling `_latest` Future, so writes
/// serialize in invocation order. [flush] awaits that tail; [close]
/// does the same and blocks further dispatches.
///
/// ```dart
/// log.info('Server started');
/// await log.progress('Migration', () async {
///   log.info('Step 1');
/// });
/// ```
class Log {
  final LogWriter _writer;
  Future<void> _latest = Future.value();
  bool _closed = false;

  /// The minimum severity that will be forwarded to the writer. Calls below
  /// this level short-circuit without invoking the [LogEntryFactory]. May
  /// be changed at runtime (e.g. when a verbose flag is parsed).
  LogLevel logLevel;

  /// Creates a [Log] that forwards to [_writer]. Messages below [logLevel]
  /// are dropped before the [LogEntryFactory] runs.
  Log(this._writer, {this.logLevel = LogLevel.info});

  /// The current writer from the Zone.
  LogWriter? get currentWriter => Zone.current[_logWriterKey] as LogWriter?;

  /// The current scope from the Zone, or a synthetic root if none.
  LogScope get currentScope =>
      Zone.current[_logScopeKey] as LogScope? ?? _fallbackScope;

  static final _fallbackScope = LogScope.root('unknown');

  /// Checks level, evaluates the factory eagerly, and appends the write
  /// to the chain. Writer errors are swallowed - logging is best-effort.
  void call(LogLevel level, LogEntryFactory factory) {
    if (level.index < logLevel.index || _closed) return;
    _latest = _latest.then((_) async {
      try {
        await _writer.log(await factory());
      } catch (_) {}
    });
  }

  /// Awaits in-flight writes without blocking further dispatches.
  Future<void> flush() => _latest;

  /// Awaits in-flight writes and blocks further dispatches.
  Future<void> close() async {
    _closed = true;
    await flush();
  }
}

/// Convenience methods for common log levels.
extension LogConvenience on Log {
  /// Logs [message] at [LogLevel.debug].
  void debug(String message, {Map<String, Object?>? metadata}) => this(
    LogLevel.debug,
    () => LogEntry(
      time: DateTime.now(),
      level: LogLevel.debug,
      message: message,
      scope: currentScope,
      metadata: metadata,
    ),
  );

  /// Logs [message] at [LogLevel.info].
  void info(String message, {Map<String, Object?>? metadata}) => this(
    LogLevel.info,
    () => LogEntry(
      time: DateTime.now(),
      level: LogLevel.info,
      message: message,
      scope: currentScope,
      metadata: metadata,
    ),
  );

  /// Logs [message] at [LogLevel.warning].
  void warning(String message, {Map<String, Object?>? metadata}) => this(
    LogLevel.warning,
    () => LogEntry(
      time: DateTime.now(),
      level: LogLevel.warning,
      message: message,
      scope: currentScope,
      metadata: metadata,
    ),
  );

  /// Logs [message] at [LogLevel.error], optionally attaching an [error]
  /// value and [stackTrace].
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? metadata,
  }) => this(
    LogLevel.error,
    () => LogEntry(
      time: DateTime.now(),
      level: LogLevel.error,
      message: message,
      scope: currentScope,
      error: error,
      stackTrace: stackTrace,
      metadata: metadata,
    ),
  );

  /// Whether debug-level messages are currently forwarded to the writer.
  /// Use to gate expensive message construction:
  /// `if (log.isDebugEnabled) log.debug(formatBigObject(x));`.
  bool get isDebugEnabled => logLevel.index <= LogLevel.debug.index;
}

/// Scope management: progress operations and manual scope control.
extension LogScoping on Log {
  /// Runs [runner] inside a new scope. The scope is automatically opened
  /// before the runner and closed after it completes (or fails).
  ///
  /// Log calls inside the runner are automatically scoped via the Zone.
  ///
  /// Success signal:
  /// - If [runner] throws, the scope closes with `success: false`.
  /// - Else if [isSuccess] is provided, its return value is used.
  /// - Else if [T] is `bool`, the returned value is used directly.
  /// - Otherwise, the scope closes with `success: true`.
  Future<T> progress<T>(
    String label,
    Future<T> Function() runner, {
    Map<String, Object?>? metadata,
    bool Function(T result)? isSuccess,
  }) async {
    return await progressStream(
      label,
      Stream.fromFuture(runner()),
      isSuccess: isSuccess,
      metadata: metadata,
    );
  }

  /// Opens a new scope, consumes [stream] updating the scope label on each
  /// event via [toMessage], then closes the scope.
  ///
  /// Success signal:
  /// - If [stream] emits an error event, the scope closes with `success: false`.
  /// - Else if [isSuccess] is provided, its return value is used.
  /// - Else if [T] is `bool`, the returned value is used directly.
  /// - Otherwise, the scope closes with `success: true`.
  Future<T> progressStream<T>(
    String initialMessage,
    Stream<T> stream, {
    String Function(T)? toMessage,
    bool Function(T)? isSuccess,
    Map<String, Object?>? metadata,
  }) async {
    final scope = currentScope.child(
      id: _newScopeId(initialMessage),
      label: initialMessage,
      metadata: metadata,
    );
    await _writer.openScope(scope);
    final stopwatch = Stopwatch()..start();
    try {
      final result = await runZoned(
        () => _consumeStream(stream, toMessage: toMessage),
        zoneValues: {_logScopeKey: scope, _logWriterKey: _writer},
      );

      await _writer.closeScope(
        scope,
        success: isSuccess?.call(result) ?? (result is bool ? result : true),
        duration: stopwatch.elapsed,
      );
      return result;
    } catch (e, st) {
      await _writer.closeScope(
        scope,
        success: false,
        duration: stopwatch.elapsed,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Iterates [stream] to completion, updating the current scope's label
  /// with [toMessage] on each event. Returns the last event, or throws a
  /// [StateError] if the stream is empty.
  Future<T> _consumeStream<T>(
    Stream<T> stream, {
    String Function(T)? toMessage,
  }) async {
    bool hasEvent = false;
    T? finalEvent;
    await for (final event in stream) {
      hasEvent = true;
      finalEvent = event;
      final message = toMessage?.call(event) ?? event.toString();
      await currentWriter?.updateScope(currentScope.copyWith(label: message));
    }
    if (!hasEvent || finalEvent is! T) {
      throw StateError('No events in stream');
    }

    return finalEvent;
  }
}
