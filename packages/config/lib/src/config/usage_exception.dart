class UsageException implements Exception {
  final String message;
  final String usage;

  UsageException(this.message, this.usage);

  @override
  String toString() => '$message\n\n$usage';
}
