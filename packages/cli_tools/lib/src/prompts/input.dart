import 'dart:io';

import '../logger/logger.dart';

/// Prompts the user for input.
/// If [defaultValue] is provided, the user can skip the prompt by pressing Enter.
Future<String> input(
  final String message, {
  final String? defaultValue,
  required final Logger logger,
}) async {
  final defaultDescription = defaultValue == null ? '' : ' ($defaultValue)';

  logger.write(
    '$message$defaultDescription: ',
    LogLevel.info,
    newLine: false,
    newParagraph: false,
  );
  final input = stdin.readLineSync()?.trim();
  final missingInput = input == null || input.isEmpty;
  if (missingInput) {
    return defaultValue ?? '';
  }

  return input;
}
