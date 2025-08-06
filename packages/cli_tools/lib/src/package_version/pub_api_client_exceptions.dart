/// An exception that is thrown when an error occurs during fetching the latest version.
class VersionFetchException implements Exception {
  final String message;
  final Object exception;
  final StackTrace stackTrace;

  VersionFetchException(this.message, this.exception, this.stackTrace);
}

/// An exception that is thrown when an error occurs during parsing the version.
class VersionParseException implements Exception {
  final String message;
  final Object exception;
  final StackTrace stackTrace;

  VersionParseException(this.message, this.exception, this.stackTrace);
}
