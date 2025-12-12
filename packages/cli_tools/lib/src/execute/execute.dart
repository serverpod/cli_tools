import 'dart:io';
import 'dart:io' as io;

import 'package:async/async.dart';

/// Executes a [command] in a child process shell and returns the exit code. The
/// [command] can include arguements, fx: `echo "Hello world!"`.
///
/// Child stdout/stderr will be forwarded to the parent process. It will use the
/// parents defaults for [stdin]/[stdout] unless overriden with alternative
/// [IOSink]s.
///
/// Parent signals (SIGINT & SIGTERM) will be forwarded to the child, while
/// [command] is running
///
/// If you pass a [stdin] stream then it will be consumed and forwarded to the
/// child. If you plan on listening to stdin again later, make sure to convert
/// it from a single subscription stream first.
///
/// You can specify what [workingDirectory] the child process should be spawned
/// in. It will default to [Directory.current].
Future<int> execute(
  final String command, {
  final Stream<List<int>>? stdin,
  IOSink? stdout,
  IOSink? stderr,
  Directory? workingDirectory,
}) async {
  stdout ??= io.stdout;
  stderr ??= io.stderr;
  workingDirectory ??= Directory.current;

  final shell = Platform.isWindows ? 'cmd' : 'bash';
  final shellArg = Platform.isWindows ? '/c' : '-c';

  // NOTE: We invoke a shell instead of the command directly (with runInShell:
  // true). This avoid a lot of edge cases regarding quoting, repeated spaces,
  // etc.
  final process = await Process.start(
    shell,
    [shellArg, command],
    workingDirectory: workingDirectory.path,
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
