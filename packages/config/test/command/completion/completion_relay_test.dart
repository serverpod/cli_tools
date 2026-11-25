/// The failures of asking another program for a completion.
///
/// A program that answers is tested with the compiled fixture CLI, in
/// `shell_integration_test.dart`.
library;

import 'dart:io';

import 'package:config/command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Given a program that does not exist', () {
    final program = p.join(Directory.systemTemp.path, 'no_such_program_4217');

    test('when requesting a completion from it '
        'then a process exception is thrown', () {
      expect(
        requestCompletionFrom(program, ['bu']),
        throwsA(isA<ProcessException>()),
      );
    });
  });

  group('Given a program that fails on the completion request', () {
    // The Dart executable has no `__complete` command.
    final program = Platform.resolvedExecutable;

    late ProcessException error;

    setUp(() async {
      error = await _captureError(() => requestCompletionFrom(program, ['']));
    });

    test('when requesting a completion from it '
        'then the failed request is reported', () {
      expect(error.message, startsWith('The completion request failed: '));
    });

    test('when requesting a completion from it '
        'then its exit code is reported', () {
      expect(error.errorCode, isNot(0));
    });

    test('when requesting a completion from it '
        'then the request is reported', () {
      expect(error.executable, program);
      expect(error.arguments, ['__complete', '']);
    });
  });

  group(
    'Given a program that succeeds and prints something else '
    'than a completion response',
    () {
      test('when requesting a completion from it '
          'then the unexpected output is reported', () async {
        final error = await _captureError(
          () => requestCompletionFrom('echo', ['bu']),
        );
        expect(error.message, 'The output is not a completion response');
      });
    },
    skip: Platform.isWindows ? 'echo is not a program on Windows' : null,
  );
}

Future<ProcessException> _captureError(
  final Future<Object?> Function() body,
) async {
  try {
    await body();
  } on ProcessException catch (error) {
    return error;
  }
  fail('no ProcessException was thrown');
}
