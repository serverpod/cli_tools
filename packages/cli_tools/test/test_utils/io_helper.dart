import 'dart:async';
import 'dart:io';

import 'mock_stdin.dart';
import 'mock_stdout.dart';

Future<({MockStdout stdout, MockStdout stderr, MockStdin stdin})>
    collectOutput<T>(
  final FutureOr<T> Function() runner, {
  final List<String> stdinLines = const [],
  final List<int> keyInputs = const [],
}) async {
  final standardOut = MockStdout();
  final standardError = MockStdout();
  final standardIn = MockStdin(textInputs: stdinLines, keyInputs: keyInputs);

  await IOOverrides.runZoned(
    () async {
      return await runner();
    },
    stdout: () => standardOut,
    stderr: () => standardError,
    stdin: () => standardIn,
  );

  return (stdout: standardOut, stderr: standardError, stdin: standardIn);
}
