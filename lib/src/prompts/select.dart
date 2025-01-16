import 'dart:io';

import 'package:cli_tools/cli_tools.dart';
import 'package:cli_tools/src/prompts/key_codes.dart';

Future<List<String>> select(
  String message, {
  required List<String> options,
  required Logger logger,
}) {
  return _interactiveSelect(
    message,
    options: options,
    logger: logger,
  );
}

Future<List<String>> multiselect(
  String message, {
  required List<String> options,
  required Logger logger,
}) {
  return _interactiveSelect(
    message,
    options: options,
    multiple: true,
    logger: logger,
  );
}

Future<List<String>> _interactiveSelect(
  String message, {
  required List<String> options,
  required Logger logger,
  bool multiple = false,
}) async {
  if (options.isEmpty) {
    throw ArgumentError('Options cannot be empty.');
  }

  int selectedIndex = 0;
  var selectedOptions = <int>{}; // To store indices of selected options

  void renderOptions() {
    _clearTerminal();
    // Print the prompt message
    logger.write(
      message,
      LogLevel.info,
      newLine: true,
    );
    // Render options with radio buttons
    for (int i = 0; i < options.length; i++) {
      var highlightRadio =
          multiple ? selectedOptions.contains(i) : i == selectedIndex;
      var radio = highlightRadio ? '(●)' : '(○)';
      var option = (i == selectedIndex)
          ? underline('$radio ${options[i]}')
          : '$radio ${options[i]}';
      logger.write(
        option,
        LogLevel.info,
        newLine: true,
      );
    }

    if (multiple) {
      logger.write(
        'Press [Space] to toggle selection, [Enter] to confirm.',
        LogLevel.info,
        newParagraph: true,
      );
    } else {
      logger.write(
        'Press [Enter] to confirm.',
        LogLevel.info,
        newParagraph: true,
      );
    }
  }

  renderOptions();

  var originalEchoMode = stdin.echoMode;
  var originalLineMode = stdin.lineMode;
  stdin.echoMode = false;
  stdin.lineMode = false;

  try {
    while (true) {
      var key = stdin.readByteSync();

      if (key == KeyCodes.leadingArrowEscapes[0]) {
        // Escape sequence for arrow keys
        var next1 = stdin.readByteSync();
        var next2 = stdin.readByteSync();
        if (next1 == KeyCodes.leadingArrowEscapes[1]) {
          if (next2 == KeyCodes.arrowUp) {
            selectedIndex =
                (selectedIndex - 1 + options.length) % options.length;
            renderOptions();
          } else if (next2 == KeyCodes.arrowDown) {
            selectedIndex = (selectedIndex + 1) % options.length;
            renderOptions();
          }
        }
      } else if (key == KeyCodes.space && multiple) {
        // Space key to toggle selection in multiple mode
        if (selectedOptions.contains(selectedIndex)) {
          selectedOptions.remove(selectedIndex);
        } else {
          selectedOptions.add(selectedIndex);
        }
        renderOptions();
      } else if (key == KeyCodes.enterCR || key == KeyCodes.enterLF) {
        // Enter key for confirmation
        if (multiple) {
          return selectedOptions.map((index) => options[index]).toList();
        } else {
          return [options[selectedIndex]];
        }
      } else if (key == KeyCodes.q) {
        throw ExitException();
      }
    }
  } finally {
    // Restore terminal settings
    stdin.echoMode = originalEchoMode;
    stdin.lineMode = originalLineMode;
  }
}

void _clearTerminal() {
  stdout.write('\x1B[2J\x1B[H');
}

String underline(
  String text,
) =>
    '\x1B[4m$text\x1B[0m';
