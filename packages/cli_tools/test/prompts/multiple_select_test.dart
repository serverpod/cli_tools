// ignore required for Dart 3.3
// ignore_for_file: unused_local_variable

import 'package:cli_tools/cli_tools.dart';
import 'package:cli_tools/src/prompts/key_codes.dart';
import 'package:cli_tools/src/prompts/select.dart';
import 'package:config/better_command_runner.dart' show ExitException;
import 'package:test/test.dart';

import '../test_utils/io_helper.dart';
import '../test_utils/prompts/key_code_sequence.dart';
import '../test_utils/prompts/option_matcher.dart';

void main() {
  var logger = StdOutLogger(LogLevel.debug);

  test(
      'Given multiselect prompt '
      'when confirms selection with enter line-feed '
      'then completes', () async {
    late Future<List<Option>> result;
    var options = [Option('Option 1'), Option('Option 2'), Option('Option 3')];

    await collectOutput(keyInputs: [KeyCodes.enterLF], () {
      result = multiselect(
        'Choose multiple options:',
        options: options,
        logger: logger,
      );
    });

    await expectLater(result, completes);
  });

  test(
      'Given multiselect prompt '
      'when confirms selection with enter carriage-return '
      'then completes', () async {
    late Future<List<Option>> result;
    var options = [Option('Option 1'), Option('Option 2'), Option('Option 3')];

    await collectOutput(keyInputs: [KeyCodes.enterCR], () {
      result = multiselect(
        'Choose multiple options:',
        options: options,
        logger: logger,
      );
    });

    await expectLater(result, completes);
  });

  test(
      'Given multiselect prompt '
      'when providing message '
      'then should be displayed first', () async {
    var (:stdout, :stderr, :stdin) = await collectOutput(
      keyInputs: [KeyCodes.enterCR],
      () {
        return multiselect(
          'Choose multiple options:',
          options: [Option('Option 1')],
          logger: logger,
        );
      },
    );

    expect(stdout.output, startsWith('Choose multiple options:\n'));
  });

  test(
      'Given select prompt '
      'when providing options '
      'then instruction should be given last', () async {
    var (:stdout, :stderr, :stdin) = await collectOutput(
      keyInputs: [KeyCodes.enterCR],
      () {
        return multiselect(
          'Choose an option:',
          options: [Option('Option 1')],
          logger: logger,
        );
      },
    );

    expect(
      stdout.output,
      endsWith('Press [Space] to toggle selection, [Enter] to confirm.\n'),
    );
  });

  test(
      'Given multiselect prompt '
      'when toggling multiple options and pressing Enter '
      'then should return all selected options', () async {
    late Future<List<Option>> result;
    var options = [Option('Option 1'), Option('Option 2'), Option('Option 3')];

    await collectOutput(
      keyInputs: [
        KeyCodes.space, // Select Option 1
        ...arrowDownSequence,
        KeyCodes.space, // Select Option 2
        KeyCodes.enterCR,
      ],
      () {
        result = multiselect(
          'Choose multiple options:',
          options: options,
          logger: logger,
        );
      },
    );

    await expectLater(
      result,
      completion(containsAllOptions([Option('Option 1'), Option('Option 2')])),
    );
  });

  test(
      'Given multiselect prompt '
      'when no options are selected and pressing Enter '
      'then should return an empty list', () async {
    late Future<List<Option>> result;
    var options = [Option('Option 1'), Option('Option 2'), Option('Option 3')];

    await collectOutput(keyInputs: [KeyCodes.enterCR], () {
      result = multiselect(
        'Choose multiple options:',
        options: options,
        logger: logger,
      );
    });

    await expectLater(result, completion(isEmpty));
  });

  test(
      'Given multiselect prompt '
      'when toggling the same option twice '
      'then should return empty list', () async {
    late Future<List<Option>> result;
    var options = [Option('Option 1'), Option('Option 2'), Option('Option 3')];

    await collectOutput(
      keyInputs: [
        KeyCodes.space, // Select option 1
        KeyCodes.space, // Deselect option 1
        KeyCodes.enterCR,
      ],
      () {
        result = multiselect(
          'Choose multiple options:',
          options: options,
          logger: logger,
        );
      },
    );

    await expectLater(result, completion(isEmpty));
  });

  test(
      'Given multiselect prompt '
      'when pressing "q" key '
      'then should throw a cancellation exception', () async {
    var options = [Option('Option 1'), Option('Option 2'), Option('Option 3')];

    var result = collectOutput(keyInputs: [KeyCodes.q], () async {
      await multiselect(
        'Choose multiple options:',
        options: options,
        logger: logger,
      );
    });

    await expectLater(
      result,
      throwsA(
        isA<ExitException>().having(
          (e) => e.exitCode,
          'exit code',
          equals(1),
        ),
      ),
    );
  });

  test(
      'Given multiselect prompt '
      'when providing empty options list '
      'then should throw ArgumentError', () async {
    expect(
      () => multiselect('Choose an option:', options: [], logger: logger),
      throwsArgumentError,
    );
  });

  test(
      'Given multiselect prompt '
      'when toggling multiple options and pressing Enter '
      'then all selected options should have filled radio button and '
      'current option should be underlined', () async {
    var (:stdout, :stderr, :stdin) = await collectOutput(
      keyInputs: [
        KeyCodes.space, // Select Option 1
        ...arrowDownSequence,
        KeyCodes.space, // Select Option 2
        KeyCodes.enterCR,
      ],
      () {
        return multiselect(
          'Choose multiple options:',
          options: [Option('Option 1'), Option('Option 2'), Option('Option 3')],
          logger: logger,
        );
      },
    );

    expect(stdout.output, '''Choose multiple options:
(●) Option 1
${underline('(●) Option 2')}
(○) Option 3

Press [Space] to toggle selection, [Enter] to confirm.
''');
  });

  test(
      'Given multiple select prompt with multiple options '
      'when moving past the last option and pressing Enter '
      'then first option is selected', () async {
    late Future<List<Option>> result;
    var options = [Option('Option 1'), Option('Option 2'), Option('Option 3')];

    await collectOutput(
      keyInputs: [
        ...arrowDownSequence, // Move to Option 2
        ...arrowDownSequence, // Move to Option 3
        ...arrowDownSequence, // Move to Option 1
        KeyCodes.space, // Select Option 1
        KeyCodes.enterCR,
      ],
      () {
        result = multiselect(
          'Choose multiple options:',
          options: options,
          logger: logger,
        );
      },
    );

    await expectLater(
      result,
      completion(containsAllOptions([Option('Option 1')])),
    );
  });

  test(
      'Given multiple select prompt with multiple options '
      'when up past the first option and pressing Enter '
      'then last option is selected', () async {
    late Future<List<Option>> result;
    var options = [Option('Option 1'), Option('Option 2'), Option('Option 3')];

    await collectOutput(
      keyInputs: [
        ...arrowUpSequence, // Move to Option 3
        KeyCodes.space, // Select Option 3
        KeyCodes.enterCR,
      ],
      () {
        result = multiselect(
          'Choose multiple options:',
          options: options,
          logger: logger,
        );
      },
    );

    await expectLater(
      result,
      completion(containsAllOptions([Option('Option 3')])),
    );
  });
}
