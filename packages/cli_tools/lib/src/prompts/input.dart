import 'dart:io';

import 'package:cli_tools/cli_tools.dart';

/// Prompts the user for input.
/// If [defaultValue] is provided, the user can skip the prompt by pressing Enter.
Future<String> input(
  String message, {
  String? defaultValue,
  required Logger logger,
}) async {
  var defaultDescription = defaultValue == null ? '' : ' ($defaultValue)';

  logger.write(
    '$message$defaultDescription: ',
    LogLevel.info,
    newLine: false,
    newParagraph: false,
  );
  var input = stdin.readLineSync()?.trim();
  var missingInput = input == null || input.isEmpty;
  if (missingInput) {
    return defaultValue ?? '';
  }

  return input;
}
