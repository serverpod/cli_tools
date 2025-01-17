import 'dart:io';

import 'package:cli_tools/cli_tools.dart';
import 'package:cli_tools/src/prompts/key_codes.dart';

class Option {
  final String name;

  Option(this.name);
}

Future<Option> select(
  String prompt, {
  required List<Option> options,
  required Logger logger,
}) async {
  return (await _interactiveSelect(
    prompt,
    options: options,
    logger: logger,
  ))
      .first;
}

Future<List<Option>> multiselect(
  String prompt, {
  required List<Option> options,
  required Logger logger,
}) {
  return _interactiveSelect(
    prompt,
    options: options,
    multiple: true,
    logger: logger,
  );
}

Future<List<Option>> _interactiveSelect(
  String message, {
  required List<Option> options,
  required Logger logger,
  bool multiple = false,
}) async {
  if (options.isEmpty) {
    throw ArgumentError('Options cannot be empty.');
  }

  _SelectState state = _SelectState(
    options: options,
    selectedIndex: 0,
    selectedOptions: <int>{},
    multiple: multiple,
  );

  _renderState(
    state: state,
    logger: logger,
    promptMessage: message,
  );

  var originalEchoMode = stdin.echoMode;
  var originalLineMode = stdin.lineMode;
  stdin.echoMode = false;
  stdin.lineMode = false;

  try {
    while (true) {
      var keyCode = stdin.readByteSync();

      var confirmSelection =
          keyCode == KeyCodes.enterCR || keyCode == KeyCodes.enterLF;
      if (confirmSelection) {
        return state.toList();
      }

      var quit = keyCode == KeyCodes.q;
      if (quit) {
        throw ExitException();
      }

      if (keyCode == KeyCodes.escapeSequenceStart) {
        var next1 = stdin.readByteSync();
        if (next1 == KeyCodes.controlSequenceIntroducer) {
          var next2 = stdin.readByteSync();
          if (next2 == KeyCodes.arrowUp) {
            state = state.prev();
          } else if (next2 == KeyCodes.arrowDown) {
            state = state.next();
          }
        }
      } else if (keyCode == KeyCodes.space && multiple) {
        state = state.toggleCurrent();
      }

      _renderState(state: state, logger: logger, promptMessage: message);
    }
  } finally {
    // Restore terminal settings
    stdin.echoMode = originalEchoMode;
    stdin.lineMode = originalLineMode;
  }
}

void _renderState({
  required _SelectState state,
  required Logger logger,
  required String promptMessage,
}) {
  _clearTerminal();

  logger.write(
    promptMessage,
    LogLevel.info,
    newLine: true,
  );

  for (int i = 0; i < state.options.length; i++) {
    var radioButton = state.currentOrContains(i) ? '(●)' : '(○)';
    var optionText = '$radioButton ${state.options[i].name}';

    logger.write(
      i == state.selectedIndex ? underline(optionText) : optionText,
      LogLevel.info,
      newLine: true,
    );
  }

  logger.write(
    state.multiple
        ? 'Press [Space] to toggle selection, [Enter] to confirm.'
        : 'Press [Enter] to confirm.',
    LogLevel.info,
    newParagraph: true,
  );
}

class _SelectState {
  final int selectedIndex;
  final Set<int> selectedOptions;
  final List<Option> options;
  final bool multiple;

  _SelectState({
    required this.options,
    required this.selectedIndex,
    required this.selectedOptions,
    required this.multiple,
  });

  _SelectState prev() {
    return _SelectState(
      options: options,
      selectedIndex: (selectedIndex - 1 + options.length) % options.length,
      selectedOptions: selectedOptions,
      multiple: multiple,
    );
  }

  _SelectState next() {
    return _SelectState(
      options: options,
      selectedIndex: (selectedIndex + 1) % options.length,
      selectedOptions: selectedOptions,
      multiple: multiple,
    );
  }

  _SelectState toggleCurrent() {
    return _SelectState(
        options: options,
        selectedIndex: selectedIndex,
        selectedOptions: selectedOptions.contains(selectedIndex)
            ? (selectedOptions..remove(selectedIndex))
            : (selectedOptions..add(selectedIndex)),
        multiple: multiple);
  }

  bool currentOrContains(int index) {
    return multiple ? selectedOptions.contains(index) : selectedIndex == index;
  }

  List<Option> toList() {
    return multiple
        ? selectedOptions.map((index) => options[index]).toList()
        : [options[selectedIndex]];
  }
}

// The clear terminal command \x1B[2J\x1B[H has the following format:
// ESC CSI n J ESC CSI H
// The first part is the Erase in Display (ED) escape sequence, where:
// ESC (Escape character, starts escape sequence) = \x1B
// CSI (Control Sequence Introducer) = [
// n = 2, which clears entire screen (and moves cursor to upper left on DOS ANSI.SYS).
// J indicates the Erase Display operation
//
// The second part is the Cursor Position escape sequence, where:
// H indicates the Cursor Position operation. It takes two parameters,
// defaulting to 1,1, which is the upper left corner of the terminal.
// See https://en.wikipedia.org/wiki/ANSI_escape_code for further info.
const eraseInDisplayControlSequence = '\x1B[2J\x1B[H';
void _clearTerminal() {
  stdout.write(eraseInDisplayControlSequence);
}

// The control sequence CSI n m, named Select Graphic Rendition (SGR), sets display attributes.
// n is the SGR parameter for the attribute to set, where 4 is for underline and 0 is for reset.
// See https://en.wikipedia.org/wiki/ANSI_escape_code for further info.
const underlineSelectGraphicRenditionControlSequence = '\x1B[4m';
const resetSelectGraphicRenditionControlSequence = '\x1B[0m';
String underline(
  String text,
) =>
    [
      underlineSelectGraphicRenditionControlSequence,
      text,
      resetSelectGraphicRenditionControlSequence
    ].join('');
