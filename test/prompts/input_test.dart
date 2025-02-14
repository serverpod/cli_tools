import 'package:cli_tools/cli_tools.dart';
import 'package:cli_tools/src/prompts/input.dart';
import 'package:test/test.dart';

import '../test_utils/io_helper.dart';

void main() {
  var logger = StdOutLogger(LogLevel.debug);

  test('Given input prompt '
      'when providing valid input "HelloWorld" '
      'then should return the input', () async {
    late Future<String> result;
    await collectOutput(stdinLines: ['HelloWorld'], () {
      result = input('Enter something', logger: logger);
    });

    await expectLater(result, completion('HelloWorld'));
  });

  test('Given input prompt '
      'when providing empty input with default value "default" '
      'then should return "default"', () async {
    late Future<String> result;
    await collectOutput(stdinLines: [''], () async {
      result = input(
        'Enter something',
        defaultValue: 'default',
        logger: logger,
      );
    });

    await expectLater(result, completion('default'));
  });

  test('Given input prompt '
      'when providing empty input without default value '
      'then should return an empty string', () async {
    late Future<String> result;
    await collectOutput(stdinLines: [''], () async {
      result = input('Enter something', logger: logger);
    });

    await expectLater(result, completion(''));
  });

  test('Given input prompt '
      'when providing input with leading and trailing spaces '
      'then should trim string', () async {
    late Future<String> result;
    await collectOutput(stdinLines: ['   hello   '], () async {
      result = input('Enter something', logger: logger);
    });

    await expectLater(result, completion('hello'));
  });

  test('Given input prompt '
      'when providing defult value '
      'then should display prompt with default value', () async {
    var (:stdout, :stderr, :stdin) = await collectOutput(
      stdinLines: [''],
      () async {
        await input('Enter something', defaultValue: 'default', logger: logger);
      },
    );

    expect(stdout.output, 'Enter something (default): ');
  });

  test('Given input prompt '
      'when providing no default value '
      'then should not display a default description', () async {
    var (:stdout, :stderr, :stdin) = await collectOutput(
      stdinLines: ['value'],
      () async {
        await input('Enter something', logger: logger);
      },
    );

    expect(stdout.output, 'Enter something: ');
  });
}
