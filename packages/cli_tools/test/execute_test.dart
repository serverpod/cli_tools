// These test depends on bash and unix specific tools (trap, exit, echo)
@TestOn('!windows')
library;

import 'dart:io';

import 'package:cli_tools/execute.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Future<String> compileDriver() async {
  final driverExe = p.join(Directory.systemTemp.path, 'execute_driver.exe');
  final result = await Process.run(
      'dart', ['compile', 'exe', 'test/execute_driver.dart', '-o', driverExe]);
  if (result.exitCode != 0) throw StateError('Failed to compile driver');
  return driverExe;
}

Future<String> _exe = compileDriver();

Future<ProcessResult> runDriver(final String command) async =>
    await Process.run(await _exe, [command]);

Future<Process> startDriver(final String command) async =>
    await Process.start(await _exe, [command]);

void main() {
  group('Given execute', () {
    test(
      'when running a command that succeeds, then the effect is expected',
      () async {
        final result = await runDriver('echo "Hello world!"');
        expect(result.exitCode, 0);
        expect(result.stdout, contains('Hello world!'));
      },
    );

    test(
      'when running a command that fails, then the exit code is propagated',
      () async {
        expect(await execute('exit 42'), 42);
      },
    );

    test(
      'when running a non-existent command, then an error happens',
      () async {
        final result = await runDriver('fhasjkhfs');
        expect(result.exitCode, isNot(0));
        expect(result.stderr, contains('not found'));
      },
    );

    test('when sending SIGINT, then it is forwarded to the child process',
        () async {
      // Use trap to catch signal in child
      final process = await startDriver(
          'trap "echo SIGINT; exit 0" INT; echo "Running"; while :; do sleep 0.1; done');

      // Collect stdout incrementally
      final stdoutBuffer = StringBuffer();
      process.stdout.transform(systemEncoding.decoder).listen((final data) {
        stdoutBuffer.write(data);
      });

      // Wait for the script to start (look for "Running" message)
      while (!stdoutBuffer.toString().contains('Running')) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      // Send SIGINT to driver
      process.kill(ProcessSignal.sigint);

      expect(await process.exitCode, 0);
      expect(stdoutBuffer.toString(), contains('SIGINT'));
    });
  });
}
