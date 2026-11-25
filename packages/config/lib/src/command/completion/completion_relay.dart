import 'dart:io' show Process, ProcessException;

import 'completion_protocol.dart';

/// Asks another program for the completion of [words], and returns its
/// response as it is.
///
/// Runs `<executable> __complete <words>`, the request that the shell
/// completion scripts send (see [completeRequestCommand]). Any program that
/// serves that request can be asked, such as one built on `CommandRunner`.
///
/// [words] are the arguments of that program typed so far. The last one is
/// the (possibly empty) word being completed.
///
/// [environment] is added to the environment of this process for the
/// program, as with [Process.run].
///
/// Used by a pass-through command to complete the arguments it passes to
/// that program:
///
/// ```dart
/// @override
/// Future<CompletionResponse> completePassThroughArgs(
///   final CommandContext<OptionDefinition, int> context,
///   final List<String> words,
/// ) => requestCompletionFrom('othertool', words);
/// ```
///
/// Throws a [ProcessException] if the program cannot be run, exits with a
/// non-zero exit code, or prints something other than a completion response,
/// as a program that does not serve the request would. Left uncaught in
/// `completePassThroughArgs`, nothing is offered and the failure is reported
/// on the completion error sink.
Future<CompletionResponse> requestCompletionFrom(
  final String executable,
  final List<String> words, {
  final Map<String, String>? environment,
}) async {
  final arguments = [completeRequestCommand, ...words];
  final result = await Process.run(
    executable,
    arguments,
    environment: environment,
  );

  if (result.exitCode != 0) {
    final details = '${result.stderr}'.trim();
    throw ProcessException(
      executable,
      arguments,
      'The completion request failed${details.isEmpty ? '' : ': $details'}',
      result.exitCode,
    );
  }

  final response = CompletionResponse.tryParse('${result.stdout}');
  if (response == null) {
    throw ProcessException(
      executable,
      arguments,
      'The output is not a completion response',
    );
  }
  return response;
}
