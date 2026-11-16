import 'dart:io' show stdout, stderr;

/// Output sinks for [CommandRunner].
class OutputSinks {
  final StringSink? _out;
  final StringSink? _err;

  /// The sink to write normal output to, e.g. usage guidance like --help output.
  StringSink get out => _out ?? stdout;

  /// The sink to write diagnostics and error messages to,
  /// e.g. when [UsageException] has been raised.
  StringSink get err => _err ?? stderr;

  const OutputSinks({
    final StringSink? out,
    final StringSink? err,
  }) : _out = out,
       _err = err;
}
