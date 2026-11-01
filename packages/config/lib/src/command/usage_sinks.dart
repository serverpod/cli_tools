import 'dart:io' show stdout, stderr;

/// Usage output sinks for [CommandRunner].
class UsageSinks {
  final StringSink? _out;
  final StringSink? _err;

  /// The sink to write usage guidance to, e.g. --help output.
  StringSink get out => _out ?? stdout;

  /// The sink to write usage error messages and guidance to,
  /// when [UsageException] has been raised.
  StringSink get err => _err ?? stderr;

  const UsageSinks({
    final StringSink? out,
    final StringSink? err,
  }) : _out = out,
       _err = err;
}
