import 'package:cli_tools/cli_tools.dart';
import 'package:cli_tools/src/prompts/key_codes.dart';
import 'package:cli_tools/src/prompts/select.dart';
import 'package:test/test.dart';
import '../test_utils/io_helper.dart';
import '../test_utils/prompts/key_code_sequence.dart';
import '../test_utils/prompts/option_matcher.dart';

void main() {
  var logger = StdOutLogger(LogLevel.debug);

  test(
      'Given select prompt '
      'when providing message '
      'then should be displayed first', () async {
    var (:stdout, :stderr, :stdin) = await collectOutput(
      keyInputs: [KeyCodes.enterCR],
      () {
        return select(
          'Choose an option:',
          options: [Option('Option 1')],
          logger: logger,
        );
      },
    );

    expect(stdout.output, startsWith('Choose an option:\n'));
  });

  test(
      'Given select prompt '
      'when providing options '
      'then instruction should be given last', () async {
    var (:stdout, :stderr, :stdin) = await collectOutput(
      keyInputs: [KeyCodes.enterCR],
      () {
        return select(
          'Choose an option:',
          options: [Option('Option 1')],
          logger: logger,
        );
      },
    );

    expect(stdout.output, endsWith('Press [Enter] to confirm.\n'));
  });

  test(
      'Given select prompt '
      'when selecting an option with Enter '
      'then should return the selected option', () async {
    late Future<Option> result;
    var options = [Option('Option 1'), Option('Option 2'), Option('Option 3')];

    await collectOutput(keyInputs: [KeyCodes.enterCR], () {
      result = select('Choose an option:', options: options, logger: logger);
    });

    await expectLater(result, completion(equalsOption(Option('Option 1'))));
  });

  test(
      'Given select prompt '
      'when confirms selection with enter line-feed '
      'then completes', () async {
    late Future<Option> result;
    var options = [Option('Option 1'), Option('Option 2'), Option('Option 3')];

    await collectOutput(keyInputs: [KeyCodes.enterLF], () {
      result = select('Choose an option:', options: options, logger: logger);
    });

    await expectLater(result, completes);
  });

  test(
      'Given select prompt '
      'when navigating with arrow keys '
      'then should return the highlighted option on Enter', () async {
    late Future<Option> result;
    var options = [Option('Option 1'), Option('Option 2'), Option('Option 3')];

    await collectOutput(
      keyInputs: [
        ...arrowDownSequence, // Go to option 2
        ...arrowDownSequence, // Go to option 3
        ...arrowUpSequence, // Go to option 2
        KeyCodes.enterCR,
      ],
      () {
        result = select('Choose an option:', options: options, logger: logger);
      },
    );

    await expectLater(result, completion(equalsOption(Option('Option 2'))));
  });

  test(
      'Given select prompt '
      'when pressing "q" key '
      'then should throw a cancellation exception', () async {
    var options = [Option('Option 1'), Option('Option 2'), Option('Option 3')];

    var result = collectOutput(keyInputs: [KeyCodes.q], () async {
      await select('Choose an option:', options: options, logger: logger);
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
      'Given select prompt '
      'when providing empty options list '
      'then should throw ArgumentError', () async {
    expect(
      () => select('Choose an option:', options: [], logger: logger),
      throwsArgumentError,
    );
  });

  test(
      'Given select prompt '
      'when highlighting second option '
      'then radio button should be filled and option underlined', () async {
    var (:stdout, :stderr, :stdin) = await collectOutput(
      keyInputs: [...arrowDownSequence, KeyCodes.enterCR],
      () {
        return select(
          'Choose an option:',
          options: [Option('Option 1'), Option('Option 2'), Option('Option 3')],
          logger: logger,
        );
      },
    );

    expect(stdout.output, '''Choose an option:
(○) Option 1
${underline('(●) Option 2')}
(○) Option 3

Press [Enter] to confirm.
''');
  });

  test(
      'Given select prompt with multiple options '
      'when moving past the last option '
      'then should wrap around to the first option', () async {
    late Future<Option> result;
    var options = [Option('Option 1'), Option('Option 2'), Option('Option 3')];

    await collectOutput(
      keyInputs: [
        ...arrowDownSequence, // Go to option 2
        ...arrowDownSequence, // Go to option 3
        ...arrowDownSequence, // Go to option 1
        KeyCodes.enterCR,
      ],
      () {
        result = select('Choose an option:', options: options, logger: logger);
      },
    );

    await expectLater(result, completion(equalsOption(Option('Option 1'))));
  });

  test(
      'Given select prompt with multiple options '
      'when moving up past the first option '
      'then should wrap around to the last option', () async {
    late Future<Option> result;
    var options = [Option('Option 1'), Option('Option 2'), Option('Option 3')];

    await collectOutput(
      keyInputs: [
        ...arrowUpSequence, // Go to option 3
        KeyCodes.enterCR,
      ],
      () {
        result = select('Choose an option:', options: options, logger: logger);
      },
    );

    await expectLater(result, completion(equalsOption(Option('Option 3'))));
  });
}
