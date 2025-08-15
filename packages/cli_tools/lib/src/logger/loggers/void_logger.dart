import '../logger.dart';

/// Logger that logs no output.
///
/// Intended to be used for testing to silence any printed output.
class VoidLogger extends Logger {
  VoidLogger() : super(LogLevel.debug);

  @override
  int? get wrapTextColumn => null;

  @override
  void debug(
    final String message, {
    final bool newParagraph = false,
    final LogType type = const RawLogType(),
  }) {}

  @override
  void info(
    final String message, {
    final bool newParagraph = false,
    final LogType type = const RawLogType(),
  }) {}

  @override
  void warning(
    final String message, {
    final bool newParagraph = false,
    final LogType type = const RawLogType(),
  }) {}

  @override
  void error(
    final String message, {
    final bool newParagraph = false,
    final StackTrace? stackTrace,
    final LogType type = const RawLogType(),
  }) {}

  @override
  void log(
    final String message,
    final LogLevel level, {
    final bool newParagraph = false,
    final LogType type = const RawLogType(),
  }) {}

  @override
  Future<void> flush() {
    return Future(() => {});
  }

  @override
  Future<bool> progress(
    final String message,
    final Future<bool> Function() runner, {
    final bool newParagraph = true,
  }) async {
    return await runner();
  }

  @override
  void write(
    final String message,
    final LogLevel logLevel, {
    final bool newParagraph = false,
    final bool newLine = true,
  }) {}
}
