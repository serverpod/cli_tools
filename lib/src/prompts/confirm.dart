import 'dart:io';

import 'package:cli_tools/cli_tools.dart';

Future<bool> confirm(
  String message, {
  bool? defaultValue,
  required Logger logger,
}) async {
  var prompt = defaultValue == null
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
    var input = stdin.readLineSync()?.trim().toLowerCase();

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
