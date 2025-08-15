import 'dart:io';

import '../logger/logger.dart';

/// Prompts the user to confirm an action.
/// Returns `true` if the user confirms, `false` otherwise.
/// If [defaultValue] is provided, the user can skip the prompt by pressing Enter.
Future<bool> confirm(
  final String message, {
  final bool? defaultValue,
  required final Logger logger,
}) async {
  final prompt = defaultValue == null
      ? '[y/n]'
      : defaultValue
          ? '[Y/n]'
          : '[y/N]';

  while (true) {
    logger.write(
      '$message $prompt: ',
      LogLevel.info,
      newLine: false,
      newParagraph: false,
    );
    final input = stdin.readLineSync()?.trim().toLowerCase();

    if (input == null || input.isEmpty) {
      if (defaultValue != null) {
        return defaultValue;
      }
      logger.info('Please enter "y" or "n".');
      continue;
    }

    if (input == 'y' || input == 'yes') {
      return true;
    } else if (input == 'n' || input == 'no') {
      return false;
    } else {
      logger.info('Invalid input. Please enter "y" or "n".');
    }
  }
}
