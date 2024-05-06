enum ExitCodeType {
  /// General errors - This code is often used to indicate generic or
  /// unspecified errors.
  general(1),

  /// Command invoked cannot execute - The specified command was found but
  /// couldn't be executed.
  commandInvokedCannotExecute(126),

  /// Command not found - The specified command was not found or couldn't be
  /// located.
  commandNotFound(127);

  const ExitCodeType(this.exitCode);
  final int exitCode;
}

/// An exception that can be thrown to exit the command with a specific exit
class ExitException implements Exception {
  /// Creates an instance of [ExitException].
  ExitException([this.exitCodeType = ExitCodeType.general]);

  /// The type of exit code to use.
  final ExitCodeType exitCodeType;

  /// The exit code to use.
  int get exitCode => exitCodeType.exitCode;
}
