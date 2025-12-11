import 'dart:io';

import 'package:async/async.dart';

/// Executes a command in a child process shell and returns the exit code.
///
/// Child stdout/stderr will be forwarded to the parent process. Parent signals
/// (SIGINT & SIGTERM) will be forwarded to the child.
///
/// If you pass a [stdin] stream then it will be consumed and forwarded to the
/// child. If you plan on listening to stdin again later, make sure to convert
/// it from a single subscription stream first.
///
/// You can specify what [workingDirectory] the child process should be spawned
/// in.
Future<int> execute(
  final String command, {
  final Stream<List<int>>? stdin,
  final Directory? workingDirectory,
}) async {
  final shell = Platform.isWindows ? 'cmd' : 'bash';
  final shellArg = Platform.isWindows ? '/c' : '-c';

  // NOTE: We invoke a shell instead of the command directly (with runInShell:
  // true). This avoid a lot of edge cases regarding quoting, repeated spaces,
  // etc.
  final process = await Process.start(
    shell,
    [shellArg, command],
    workingDirectory: workingDirectory?.path,
  );

  // Forward signals to child process
  final sigSubscription = StreamGroup.merge(
    [
      ProcessSignal.sigint,
      if (!Platform.isWindows) ProcessSignal.sigterm,
    ].map((final s) => s.watch()),
  ).listen((final s) {
    process.kill(s);
  });

  // Forward stdin to the child process
  final stdinSubscription = stdin?.listen(
    process.stdin.add,
    cancelOnError: true,
    onError: (final _) {}, // extremely unlikely, but why not
  );

  // Stream output directly to terminal
  await [
    stdout.addStream(process.stdout),
    stderr.addStream(process.stderr),
  ].wait;
  await stdinSubscription?.cancel();
  await process.stdin.close();
  await sigSubscription.cancel();

  return await process.exitCode;
}
