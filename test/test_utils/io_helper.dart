import 'dart:async';
import 'dart:io';

import 'mock_stdin.dart';
import 'mock_stdout.dart';

Future<({MockStdout stdout, MockStdout stderr, MockStdin stdin})>
    collectOutput<T>(
  FutureOr<T> Function() runner, {
  List<String> stdinLines = const [],
}) async {
  var standardOut = MockStdout();
  var standardError = MockStdout();
  var standardIn = MockStdin(stdinLines);

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
