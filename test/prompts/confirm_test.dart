// ignore required for Dart 3.3
// ignore_for_file: unused_local_variable

import 'package:cli_tools/cli_tools.dart';
import 'package:test/test.dart';

import '../test_utils/io_helper.dart';

void main() {
  var logger = StdOutLogger(LogLevel.debug);

  test(
      'Given confirm prompt '
      'when providing valid input "yes" '
      'then should return true', () async {
    late Future<bool> result;
    await collectOutput(stdinLines: ['yes'], () {
      result = confirm('Are you sure?', logger: logger);
    });

    await expectLater(result, completion(isTrue));
  });

  test(
      'Given confirm prompt '
      'when providing valid input "y" '
      'then should return true', () async {
    late Future<bool> result;
    await collectOutput(stdinLines: ['y'], () {
      result = confirm('Are you sure?', logger: logger);
    });

    await expectLater(result, completion(isTrue));
  });

  test(
      'Given confirm prompt '
      'when providing valid input capital "Y" '
      'then should return true', () async {
    late Future<bool> result;
    await collectOutput(stdinLines: ['Y'], () {
      result = confirm('Are you sure?', logger: logger);
    });

    await expectLater(result, completion(isTrue));
  });

  test(
      'Given confirm prompt '
      'when providing valid input "no" '
      'then should return false', () async {
    late Future<bool> result;
    await collectOutput(stdinLines: ['no'], () async {
      result = confirm('Are you sure?', logger: logger);
    });

    await expectLater(result, completion(isFalse));
  });

  test(
      'Given confirm prompt '
      'when providing valid input "n" '
      'then should return false', () async {
    late Future<bool> result;
    await collectOutput(stdinLines: ['n'], () async {
      result = confirm('Are you sure?', logger: logger);
    });

    await expectLater(result, completion(isFalse));
  });

  test(
      'Given confirm prompt '
      'when providing valid input capital "N" '
      'then should return false', () async {
    late Future<bool> result;
    await collectOutput(stdinLines: ['N'], () async {
      result = confirm('Are you sure?', logger: logger);
    });

    await expectLater(result, completion(isFalse));
  });

  test(
      'Given confirm prompt '
      'when providing invalid input "invalid" and then valid input "yes" '
      'then should prompt again and return true', () async {
    late Future<bool> result;
    var (:stdout, :stderr, :stdin) = await collectOutput(
      stdinLines: ['invalid', 'yes'],
      () {
        result = confirm('Are you sure?', logger: logger);
      },
    );

    expect(
      stdout.output,
      'Are you sure? [y/n]: '
      'Invalid input. Please enter "y" or "n".\n'
      'Are you sure? [y/n]: ',
    );

    await expectLater(result, completion(isTrue));
  });

  test(
      'Given confirm prompt '
      'when providing empty input with default value false '
      'then should return false', () async {
    late bool result;
    await collectOutput(stdinLines: ['  '], () async {
      result = await confirm(
        'Are you sure?',
        defaultValue: false,
        logger: logger,
      );
    });

    await expectLater(result, isFalse);
  });

  test(
      'Given confirm prompt '
      'when providing empty input with default value true '
      'then should return true', () async {
    late Future<bool> result;
    await collectOutput(stdinLines: ['  '], () {
      result = confirm('Are you sure?', defaultValue: true, logger: logger);
    });

    await expectLater(result, completion(isTrue));
  });

  test(
      'Given confirm prompt '
      'when providing empty input and then "yes" without default value '
      'then should prompt again and return true', () async {
    late Future<bool> result;
    var (:stdout, :stderr, :stdin) = await collectOutput(
      stdinLines: ['  ', 'yes'],
      () {
        result = confirm('Are you sure?', logger: logger);
      },
    );

    expect(
      stdout.output,
      'Are you sure? [y/n]: '
      'Please enter "y" or "n".\n'
      'Are you sure? [y/n]: ',
    );

    await expectLater(result, completion(isTrue));
  });

  test(
      'Given confirm prompt '
      'when providing no default value '
      'then should prompt with lowercase "y" and "n"', () async {
    var (:stdout, :stderr, :stdin) = await collectOutput(
      stdinLines: ['yes'],
      () async {
        await confirm('Are you sure?', logger: logger);
      },
    );

    expect(stdout.output, 'Are you sure? [y/n]: ');
  });

  test(
      'Given confirm prompt '
      'when providing default value true '
      'then should prompt with uppercase "Y" and lowercase "n"', () async {
    var (:stdout, :stderr, :stdin) = await collectOutput(
      stdinLines: ['yes'],
      () async {
        await confirm('Are you sure?', defaultValue: true, logger: logger);
      },
    );

    expect(stdout.output, 'Are you sure? [Y/n]: ');
  });

  test(
      'Given confirm prompt '
      'when providing default value false '
      'then should prompt with lowercase "y" and uppercase "N"', () async {
    var (:stdout, :stderr, :stdin) = await collectOutput(
      stdinLines: ['yes'],
      () async {
        await confirm('Are you sure?', defaultValue: false, logger: logger);
      },
    );

    expect(stdout.output, 'Are you sure? [y/N]: ');
  });
}
