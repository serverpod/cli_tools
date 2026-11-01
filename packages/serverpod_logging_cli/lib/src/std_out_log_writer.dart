import 'package:cli_tools/cli_tools.dart' as cli;
import 'package:serverpod_logging/serverpod_logging.dart';

/// Metadata key used to pass [cli.LogType] through [LogEntry.metadata].
const logTypeKey = 'serverpod:logType';

/// Maps a [LogLevel] to the [cli.LogLevel].
cli.LogLevel toCliLogLevel(LogLevel level) => switch (level) {
  LogLevel.debug => cli.LogLevel.debug,
  LogLevel.info => cli.LogLevel.info,
  LogLevel.warning => cli.LogLevel.warning,
  LogLevel.error || LogLevel.fatal => cli.LogLevel.error,
};

/// A [TextLogWriter] that renders log lines through a [cli.StdOutLogger],
/// adding [cli.LogType]-aware formatting, ie. bullets, headers, boxes, Windows
/// emoji replacements, etc.
class StdOutLogWriter extends TextLogWriter {
  final cli.StdOutLogger _logger;

  StdOutLogWriter({Map<String, String>? replacements})
    : _logger = cli.StdOutLogger(
        // Accept all levels - filtering is done by Log, not the writer.
        cli.LogLevel.debug,
        replacements: replacements,
        // Match TextLogWriter: errors and above go to stderr.
        logToStderrLevelThreshold: cli.LogLevel.error,
      );

  @override
  void writeLogLine(LogEntry entry) {
    final type =
        entry.metadata?[logTypeKey] as cli.LogType? ?? cli.TextLogType.normal;
    if (entry.level == LogLevel.error || entry.level == LogLevel.fatal) {
      _logger.error(entry.message, stackTrace: entry.stackTrace, type: type);
    } else {
      _logger.log(entry.message, toCliLogLevel(entry.level), type: type);
    }
  }
}
