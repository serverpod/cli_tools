import 'dart:io';
import 'dart:math' as math;

import 'package:super_string/super_string.dart';

import '../helpers/ansi_style.dart';
import '../helpers/progress.dart';
import '../logger.dart';

/// Logger that logs using the [Stdout] library.
/// Errors and Warnings are printed on [stderr] and other messages are logged
/// on [stdout].
class StdOutLogger extends Logger {
  static const int _defaultColumnWrap = 80;

  static String _levelPrefix(final LogLevel level) {
    return switch (level) {
      LogLevel.debug => 'DEBUG: ',
      LogLevel.info => '',
      LogLevel.warning => 'WARNING: ',
      LogLevel.error => 'ERROR: ',
      LogLevel.nothing => '',
    };
  }

  Progress? trackedAnimationInProgress;

  /// [logToStderrLevelThreshold] is the log level threshold at which messages
  /// are written to [stderr] instead of [stdout].
  /// If null (the default), messages are written to [stdout] for all log levels.
  final LogLevel? logToStderrLevelThreshold;

  final Map<String, String>? _replacements;

  /// Creates a new [StdOutLogger].
  ///
  /// [logToStderrLevelThreshold] is the log level threshold at which messages
  /// are written to [stderr] instead of [stdout].
  /// If null (the default), messages are written to [stdout] for all log levels.
  StdOutLogger(
    super.logLevel, {
    final Map<String, String>? replacements,
    this.logToStderrLevelThreshold,
  }) : _replacements = replacements;

  @override
  int? get wrapTextColumn => stdout.hasTerminal ? stdout.terminalColumns : null;

  @override
  void debug(
    final String message, {
    final bool newParagraph = false,
    final LogType type = TextLogType.normal,
  }) {
    log(message, LogLevel.debug, newParagraph: newParagraph, type: type);
  }

  @override
  void info(
    final String message, {
    final bool newParagraph = false,
    final LogType type = TextLogType.normal,
  }) {
    log(message, LogLevel.info, newParagraph: newParagraph, type: type);
  }

  @override
  void warning(
    final String message, {
    final bool newParagraph = false,
    final LogType type = TextLogType.normal,
  }) {
    log(message, LogLevel.warning, newParagraph: newParagraph, type: type);
  }

  @override
  void error(
    final String message, {
    final bool newParagraph = false,
    final StackTrace? stackTrace,
    final LogType type = TextLogType.normal,
  }) {
    final msg =
        stackTrace != null ? '$message\n${stackTrace.toString()}' : message;

    log(msg, LogLevel.error, newParagraph: newParagraph, type: type);
  }

  @override
  void log(
    final String message,
    final LogLevel level, {
    final bool newParagraph = false,
    final LogType type = TextLogType.normal,
  }) {
    if (ansiSupported) {
      final ansiMessage = switch (level) {
        LogLevel.debug => AnsiStyle.darkGray.wrap(message),
        LogLevel.info => message,
        LogLevel.warning => AnsiStyle.yellow.wrap(message),
        LogLevel.error => AnsiStyle.red.wrap(message),
        LogLevel.nothing => message,
      };

      _log(ansiMessage, level, newParagraph, type);
    } else {
      final prefix = _levelPrefix(level);

      _log(message, level, newParagraph, type, prefix: prefix);
    }
  }

  @override
  Future<bool> progress(
    final String message,
    final Future<bool> Function() runner, {
    final bool newParagraph = false,
  }) async {
    if (logLevel.index > LogLevel.info.index) {
      return await runner();
    }

    _stopAnimationInProgress();

    // Write an empty line before the progress message if a new paragraph is
    // requested.
    if (newParagraph) {
      write('', LogLevel.info, newParagraph: false, newLine: true);
    }

    final progress = Progress(message, stdout);
    trackedAnimationInProgress = progress;
    final bool success = await runner();
    trackedAnimationInProgress = null;
    success ? progress.complete() : progress.fail();
    return success;
  }

  @override
  Future<void> flush() async {
    await stderr.flush();
    await stdout.flush();
  }

  bool shouldLog(final LogLevel logLevel) {
    return logLevel.index >= this.logLevel.index;
  }

  void _log(
    String message,
    final LogLevel logLevel,
    final bool newParagraph,
    final LogType type, {
    final String prefix = '',
  }) {
    if (message == '') return;
    if (!shouldLog(logLevel)) return;

    if (type is BoxLogType) {
      message = _formatAsBox(
        wrapColumn: wrapTextColumn ?? _defaultColumnWrap,
        message: message,
        title: type.title,
      );
    } else if (type is TextLogType) {
      switch (type.style) {
        case TextLogStyle.command:
          message = '   ${AnsiStyle.cyan.wrap('\$')} $message';
          break;
        case TextLogStyle.bullet:
          message = ' • $message';
          break;
        case TextLogStyle.normal:
          message = '$prefix$message';
          break;
        case TextLogStyle.init:
          message = AnsiStyle.cyan.wrap(AnsiStyle.bold.wrap(message));
          break;
        case TextLogStyle.header:
          message = AnsiStyle.bold.wrap(message);
          break;
        case TextLogStyle.success:
          message =
              '✅ ${AnsiStyle.lightGreen.wrap(AnsiStyle.bold.wrap(message))}\n';
          break;
        case TextLogStyle.hint:
          message = AnsiStyle.darkGray.wrap(AnsiStyle.italic.wrap(message));
          break;
      }

      message = _wrapText(message, wrapTextColumn ?? _defaultColumnWrap);
    }

    write(
      message,
      logLevel,
      newParagraph: newParagraph,
      newLine: type is! RawLogType,
    );
  }

  @override
  void write(
    String message,
    final LogLevel logLevel, {
    final newParagraph = false,
    final newLine = true,
  }) {
    message = switch (_replacements) {
      null => message,
      final Map<String, String> replacements => replacements.entries.fold(
          message,
          (final String acc, final entry) =>
              acc.replaceAll(entry.key, entry.value),
        ),
    };

    _stopAnimationInProgress();
    final output = '${newParagraph ? '\n' : ''}$message${newLine ? '\n' : ''}';
    final threshold = logToStderrLevelThreshold;
    if (threshold != null && logLevel.index >= threshold.index) {
      stderr.write(output);
    } else {
      stdout.write(output);
    }
  }

  void _stopAnimationInProgress() {
    if (trackedAnimationInProgress != null) {
      trackedAnimationInProgress?.stopAnimation();
      // Since animation modifies the current line we add a new line so that
      // the next print doesn't end up on the same line.
      stdout.write('\n');
    }

    trackedAnimationInProgress = null;
  }
}

/// wrap text based on column width
String _wrapText(final String text, final int columnWidth) {
  final textLines = text.split('\n');
  final List<String> outLines = [];
  for (var line in textLines) {
    final leadingTrimChar = _tryGetLeadingTrimmableChar(line);
    // wordWrap(...) uses trim as part of its implementation which removes all
    // leading trimmable characters.
    // In order to preserve them we temporarily replace the first char with a
    // non trimmable character.
    if (leadingTrimChar != null) {
      line = '@${line.substring(1)}';
    }

    var wrappedLine = line.wordWrap(width: columnWidth);

    if (leadingTrimChar != null) {
      wrappedLine = '$leadingTrimChar${wrappedLine.substring(1)}';
    }
    outLines.add(wrappedLine);
  }

  return outLines.join('\n');
}

String? _tryGetLeadingTrimmableChar(final String text) {
  if (text.isNotEmpty && text.first.trim().isEmpty) {
    return text.first;
  }

  return null;
}

/// Wraps the message in a box.
///
///  Example output:
///
///   ┌─ [title] ─┐
///   │ [message] │
///   └───────────┘
///
/// When [title] is provided, the box will have a title above it.
String _formatAsBox({
  required final String message,
  final String? title,
  required final int wrapColumn,
}) {
  const int kPaddingLeftRight = 1;
  const int kEdges = 2;

  final maxTextWidthPerLine = wrapColumn - kEdges - kPaddingLeftRight * 2;
  final lines = _wrapText(message, maxTextWidthPerLine).split('\n');
  final lineWidth = lines.map((final String line) => line.length).toList();
  final maxColumnSize = lineWidth.reduce(
    (final int currLen, final int maxLen) => math.max(currLen, maxLen),
  );
  final textWidth = math.min(maxColumnSize, maxTextWidthPerLine);
  final textWithPaddingWidth = textWidth + kPaddingLeftRight * 2;

  final buffer = StringBuffer();

  // Write `┌─ [title] ─┐`.
  buffer.write('┌');
  buffer.write('─');
  if (title == null) {
    buffer.write('─' * (textWithPaddingWidth - 1));
  } else {
    buffer.write(' $title ');
    buffer.write('─' * (textWithPaddingWidth - title.length - 3));
  }
  buffer.write('┐');
  buffer.write('\n');

  // Write `│ [message] │`.
  for (int lineIdx = 0; lineIdx < lines.length; lineIdx++) {
    buffer.write('│');
    buffer.write(' ' * kPaddingLeftRight);
    buffer.write(lines[lineIdx]);
    final remainingSpacesToEnd = textWidth - lineWidth[lineIdx];
    buffer.write(' ' * (remainingSpacesToEnd + kPaddingLeftRight));
    buffer.write('│');
    buffer.write('\n');
  }

  // Write `└───────────┘`.
  buffer.write('└');
  buffer.write('─' * textWithPaddingWidth);
  buffer.write('┘');

  return buffer.toString();
}
