import 'dart:io';

/// An exception that is thrown when the platform is not supported.
class UnsupportedPlatformException implements Exception {
  static const String message = 'Unsupported platform.';

  const UnsupportedPlatformException();
}

/// An exception that is thrown when an error occurs during file deletion.
class DeleteException implements Exception {
  final File file;
  final Object error;
  final StackTrace stackTrace;

  DeleteException(this.file, this.error, this.stackTrace);
}

/// An exception that is thrown when an error occurs during file creation.
class CreateException implements Exception {
  final File file;
  final Object error;
  final StackTrace stackTrace;

  CreateException(this.file, this.error, this.stackTrace);
}

/// An exception that is thrown when an error occurs during file writing.
class WriteException implements Exception {
  final File file;
  final Object error;
  final StackTrace stackTrace;

  WriteException(this.file, this.error, this.stackTrace);
}

/// An exception that is thrown when an error occurs during serialization.
class SerializationException implements Exception {
  final Map<String, dynamic> object;
  final Object error;
  final StackTrace stackTrace;

  SerializationException(this.object, this.error, this.stackTrace);
}

/// An exception that is thrown when an error occurs during file reading.
class ReadException implements Exception {
  final File file;
  final Object error;
  final StackTrace stackTrace;

  ReadException(this.file, this.error, this.stackTrace);
}

/// An exception that is thrown when an error occurs during deserialization.
class DeserializationException implements Exception {
  final File file;
  final Object error;
  final StackTrace stackTrace;

  DeserializationException(this.file, this.error, this.stackTrace);
}
