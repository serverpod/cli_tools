import 'dart:io' show stdout, stderr;

/// Usage output settings for [CommandRunner].
class UsageOutputSettings {
  final StringSink? _out;
  final StringSink? _err;

  /// The sink to write usage guidance to, e.g. --help output.
  StringSink get out => _out ?? stdout;

  /// The sink to write usage error messages and guidance to,
  /// when [UsageException] has been raised.
  StringSink get err => _err ?? stderr;

  /// Set to true for [CommandRunner.runner] to not throw [UsageException]
  /// on parsing and configuration input errors.
  final bool noUsageException;

  /// Set to true for [CommandRunner.runner] to not print usage guidance on
  /// parsing and configuration input errors.
  final bool noUsageExceptionOutput;

  const UsageOutputSettings({
    final StringSink? out,
    final StringSink? err,
    final bool? noUsageException,
    final bool? noUsageExceptionOutput,
  }) : _out = out,
       _err = err,
       noUsageException = noUsageException ?? false,
       noUsageExceptionOutput = noUsageExceptionOutput ?? false;
}
