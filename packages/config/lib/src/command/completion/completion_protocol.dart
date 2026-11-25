import 'dart:convert' show LineSplitter;

import '../../config/completion.dart';

/// The hidden built-in root command word that serves completion requests
/// from the shell completion scripts.
///
/// The request has the form:
/// ```
/// <executable> __complete <word>... <word-to-complete>
/// ```
/// where the words are the command line arguments typed so far and the last
/// word is the (possibly empty) partial word being completed.
///
/// The response on stdout is one line per completion candidate, in the form
/// `value` or `value<TAB>description`, followed by a final line `:<N>`
/// where N is the sum of the [CompletionDirective] flags.
///
/// This is the protocol of Cobra's `__complete` command, which is understood
/// by third-party completion engines such as Carapace.
const String completeRequestCommand = '__complete';

/// Flags that instruct the shell how to treat the completion response.
///
/// Compatible with Cobra's ShellCompDirective values.
abstract final class CompletionDirective {
  /// An error occurred, the shell should offer nothing.
  static const int error = 1;

  /// Do not append a space after a single inserted candidate.
  static const int noSpace = 2;

  /// Do not fall back to file completion when there are no candidates.
  static const int noFileCompletion = 4;

  /// Perform file completion restricted to the file extensions listed as
  /// candidate lines (without a leading dot).
  static const int filterFileExtensions = 8;

  /// Perform directory completion only.
  static const int filterDirectories = 16;

  /// Present the candidates in the given order instead of sorting them.
  static const int keepOrder = 32;

  /// Plain candidates with file completion fallback.
  static const int defaultDirective = 0;
}

/// The response to a completion request, see [completeRequestCommand].
class CompletionResponse {
  /// The candidate lines. For [CompletionDirective.filterFileExtensions]
  /// these are the file extensions.
  final List<CompletionCandidate> candidates;

  /// The sum of the [CompletionDirective] flags.
  final int directive;

  const CompletionResponse(
    this.candidates, {
    required this.directive,
  });

  /// A response with no candidates where the shell offers nothing.
  const CompletionResponse.nothing()
    : candidates = const [],
      directive = CompletionDirective.noFileCompletion;

  /// A response with no candidates where the shell performs native file
  /// completion.
  const CompletionResponse.files()
    : candidates = const [],
      directive = CompletionDirective.defaultDirective;

  /// A response indicating that an error occurred.
  const CompletionResponse.error()
    : candidates = const [],
      directive = CompletionDirective.error;

  /// Converts a [CompletionResult] of an option value into a response.
  ///
  /// [prefix] is prepended to every candidate value, used when only the
  /// trailing part of the word was completed (e.g. after a list separator).
  factory CompletionResponse.fromResult(
    final CompletionResult result, {
    final String prefix = '',
  }) {
    switch (result.pathMode) {
      case CompletionPathMode.directories:
        return const CompletionResponse(
          [],
          directive: CompletionDirective.filterDirectories,
        );
      case CompletionPathMode.files:
        if (result.fileExtensions.isEmpty) {
          return const CompletionResponse.files();
        }
        return CompletionResponse(
          [for (final ext in result.fileExtensions) CompletionCandidate(ext)],
          directive: CompletionDirective.filterFileExtensions,
        );
      case CompletionPathMode.none:
        var directive = CompletionDirective.noFileCompletion;
        if (result.noSpace) directive |= CompletionDirective.noSpace;
        return CompletionResponse(
          [
            for (final candidate in result.candidates)
              prefix.isEmpty
                  ? candidate
                  : CompletionCandidate(
                      '$prefix${candidate.value}',
                      description: candidate.description,
                    ),
          ],
          directive: directive,
        );
    }
  }

  /// Parses a response in the wire format, the inverse of [format].
  ///
  /// Returns null if [text] does not end with a directive line, i.e. it is
  /// not a completion response. The directive is kept as it is, including
  /// flags this version does not know.
  static CompletionResponse? tryParse(final String text) {
    final lines = LineSplitter.split(
      text,
    ).where((final line) => line.isNotEmpty).toList();
    if (lines.isEmpty) return null;
    final digits = _directiveLine.firstMatch(lines.removeLast())?[1];
    final directive = digits == null ? null : int.tryParse(digits);
    if (directive == null) return null;

    return CompletionResponse(
      [for (final line in lines) _parseCandidate(line)],
      directive: directive,
    );
  }

  static final _directiveLine = RegExp(r'^:(\d+)$');

  /// A candidate line: `value` or `value<TAB>description`.
  static CompletionCandidate _parseCandidate(final String line) {
    final tab = line.indexOf('\t');
    if (tab < 0) return CompletionCandidate(line);
    final description = line.substring(tab + 1);
    return CompletionCandidate(
      line.substring(0, tab),
      description: description.isEmpty ? null : description,
    );
  }

  /// Whether the shell may fall back to file completion.
  bool get allowsFileCompletion =>
      directive & CompletionDirective.noFileCompletion == 0 &&
      directive & CompletionDirective.error == 0;

  /// Formats the response in the wire format, see [completeRequestCommand].
  String format() {
    final buffer = StringBuffer();
    for (final candidate in candidates) {
      buffer.write(_sanitizeValue(candidate.value));
      final description = candidate.description;
      if (description != null && description.isNotEmpty) {
        buffer.write('\t');
        buffer.write(_sanitizeDescription(description));
      }
      buffer.writeln();
    }
    buffer.writeln(':$directive');
    return buffer.toString();
  }

  /// One or more line or field separators, which values and descriptions
  /// must not contain.
  static const _separators = r'[\t\r\n]+';

  /// The value is the text to insert, so the spaces at its ends are kept.
  /// Separators are dropped at the ends and replaced by a space elsewhere.
  static String _sanitizeValue(final String text) {
    return text
        .replaceAll(RegExp('^$_separators|$_separators\$'), '')
        .replaceAll(RegExp(_separators), ' ');
  }

  static String _sanitizeDescription(final String text) {
    return text.replaceAll(RegExp(_separators), ' ').trim();
  }
}
