/// Formats a configuration error message.
String formatConfigError(final String error) {
  if (error.isEmpty) return error;
  final suffix = _isPunctuation(error.substring(error.length - 1)) ? '' : '.';
  return '${error[0].toUpperCase()}${error.substring(1)}$suffix';
}

/// Returns true if the character is a punctuation mark.
bool _isPunctuation(final String char) {
  return RegExp(r'\p{P}', unicode: true).hasMatch(char);
}
