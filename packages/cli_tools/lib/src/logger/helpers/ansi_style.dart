import 'dart:io';

bool? _ansiSupportedRef;

/// Returns true if the terminal supports ANSI escape codes.
bool get ansiSupported {
  return _ansiSupportedRef ??= stdout.hasTerminal && stdout.supportsAnsiEscapes;
}

/// Standard ANSI escape code for customizing terminal text output.
///
/// [Source](https://en.wikipedia.org/wiki/ANSI_escape_code#Colors)
enum AnsiStyle {
  terminalDefault('\x1B[39m'),
  red('\x1B[91m'),
  yellow('\x1B[33m'),
  blue('\x1B[34m'),
  cyan('\x1B[36m'),
  lightGreen('\x1B[92m'),
  darkGray('\x1B[90m'),
  bold('\x1B[1m'),
  italic('\x1B[3m'),
  _reset('\x1B[0m');

  /// Creates a new instance of [AnsiStyle].
  const AnsiStyle(this.ansiCode);

  /// The ANSI escape code for the style.
  final String ansiCode;

  /// Wraps text with ansi escape code for style if stdout has terminal and
  /// supports ansi escapes.
  String wrap(final String text) {
    if (!ansiSupported) {
      return text;
    }

    return '$ansiCode$text${AnsiStyle._reset.ansiCode}';
  }
}
