import '../../config/completion.dart';

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

  /// Whether the shell may fall back to file completion.
  bool get allowsFileCompletion =>
      directive & CompletionDirective.noFileCompletion == 0 &&
      directive & CompletionDirective.error == 0;

  /// Formats the response in the wire format, see [completeRequestCommand].
  String format() {
    final buffer = StringBuffer();
    for (final candidate in candidates) {
      buffer.write(_sanitize(candidate.value));
      final description = candidate.description;
      if (description != null && description.isNotEmpty) {
        buffer.write('\t');
        buffer.write(_sanitize(description));
      }
      buffer.writeln();
    }
    buffer.writeln(':$directive');
    return buffer.toString();
  }

  /// Values and descriptions must not contain line or field separators.
  static String _sanitize(final String text) {
    return text.replaceAll(RegExp(r'[\t\r\n]+'), ' ').trim();
  }
}
