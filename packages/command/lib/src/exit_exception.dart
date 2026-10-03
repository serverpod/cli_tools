/// An exception that can be thrown to exit the command with a specific exit code.
class ExitException implements Exception {
  /// Successful termination - The command was successful.
  static const int codeOk = 0;

  /// General errors - This code is often used to indicate generic or
  /// unspecified errors.
  static const int codeError = 1;

  /// The exit code to use.
  final int exitCode;

  /// Creates an instance of [ExitException] with a given exit code.
  ExitException(this.exitCode);

  /// Creates an instance of [ExitException] with an OK exit code (0).
  ExitException.ok() : exitCode = codeOk;

  /// Creates an instance of [ExitException] with a general error exit code (1).
  ExitException.error() : exitCode = codeError;
}
