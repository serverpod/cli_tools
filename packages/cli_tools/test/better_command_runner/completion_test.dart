import 'package:cli_tools/better_command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  test(
      'Given a BetterCommandRunner without enabling experimental completion feature'
      ' when running base command with --help flag'
      ' then global usage does not include "completion" command', () async {
    final infos = <String>[];
    final messageOutput = MessageOutput(
      usageLogger: (final u) => infos.add(u),
    );
    final runner = BetterCommandRunner(
      'test',
      'test project',
      messageOutput: messageOutput,
    );

    await runner.run(['--help']);

    expect(infos, hasLength(1));
    expect(
      infos.single,
      isNot(stringContainsInOrder([
        'Generate a command line completion specification',
      ])),
    );
  });

  group(
      'Given a BetterCommandRunner with experimental completion feature enabled',
      () {
    final infos = <String>[];
    final messageOutput = MessageOutput(
      usageLogger: (final u) => infos.add(u),
    );

    final runner = BetterCommandRunner(
      'test',
      'test project',
      messageOutput: messageOutput,
      experimentalCompletionCommand: true,
    );

    setUp(() {
      infos.clear();
    });

    test(
        'when running base command with --help flag '
        'then global usage includes "completion" command', () async {
      await runner.run(['--help']);

      expect(infos, hasLength(1));
      expect(
        infos.single,
        stringContainsInOrder([
          'Usage: test <command> [arguments]',
          'Global options:',
          '-h, --help',
          'Available commands:',
          'completion',
          'Generate a command line completion specification',
        ]),
      );
    });

    test(
        'when running subcommand "completion -t completely -f <file>" '
        'then a proper completely specification is written to the file',
        () async {
      await d.dir('test-dir').create();
      final filePath = p.join(d.sandbox, 'test-dir', 'test.yaml');

      await runner.run(['completion', '-t', 'completely', '-f', filePath]);

      final spec = d.file(
          filePath,
          stringContainsInOrder([
            'test:',
            '  - completion',
            '  - --quiet',
            '  - -q',
            '  - --verbose',
            '  - -v',
            'test completion*--target:',
            '  - completely',
            '  - carapace',
            'test completion*-t:',
            '  - completely',
            '  - carapace',
            'test completion*--file:',
            '  - <file>',
            'test completion*-f:',
            '  - <file>',
          ]));
      await expectLater(spec.validate(), completes);
    });

    test(
        'when running subcommand "completion -t completely -e other-exec-name -f <file>" '
        'then the completely specification contains other-exec-name', () async {
      await d.dir('test-dir').create();
      final filePath = p.join(d.sandbox, 'test-dir', 'test.yaml');

      await runner.run([
        'completion',
        '-t',
        'completely',
        '-e',
        'other-exec-name',
        '-f',
        filePath,
      ]);

      final spec = d.file(
          filePath,
          stringContainsInOrder([
            'other-exec-name:',
            '  - completion',
            '  - --quiet',
            '  - -q',
            '  - --verbose',
            '  - -v',
            'other-exec-name completion*--target:',
            '  - completely',
            '  - carapace',
            'other-exec-name completion*-t:',
            '  - completely',
            '  - carapace',
            'other-exec-name completion*--file:',
            '  - <file>',
            'other-exec-name completion*-f:',
            '  - <file>',
          ]));
      await expectLater(spec.validate(), completes);
    });

    test(
        'when running subcommand "completion -t carapace -f <file>" '
        'then a proper carapace specification is written to the file',
        () async {
      await d.dir('test-dir').create();
      final filePath = p.join(d.sandbox, 'test-dir', 'test.yaml');

      await runner.run(['completion', '-t', 'carapace', '-f', filePath]);

      final spec = d.file(
          filePath,
          stringContainsInOrder([
            r'# yaml-language-server: $schema=https://carapace.sh/schemas/command.json',
            'name: test',
            'persistentFlags:',
            '  -q, --quiet: Suppress all cli output. Is overridden by  -v, --verbose.',
            '  -v, --verbose: Prints additional information useful for development. Overrides --q, --quiet.',
            'commands:',
            '  - name: completion',
            '    flags:',
            '      -t, --target=!: The target tool format',
            '      -e, --exec-name=: Override the name of the executable',
            '      -f, --file=: Write the specification to a file instead of stdout',
            '    completion:',
            '      flag:',
            '        target: ["completely", "carapace"]',
            r'        file: ["$files"]',
          ]));
      await expectLater(spec.validate(), completes);
    });

    test(
        'when running subcommand "completion -t carapace -e other-exec-name -f <file>" '
        'then the carapace specification contains other-exec-name', () async {
      await d.dir('test-dir').create();
      final filePath = p.join(d.sandbox, 'test-dir', 'test.yaml');

      await runner.run([
        'completion',
        '-t',
        'carapace',
        '-e',
        'other-exec-name',
        '-f',
        filePath,
      ]);

      final spec = d.file(
          filePath,
          stringContainsInOrder([
            r'# yaml-language-server: $schema=https://carapace.sh/schemas/command.json',
            'name: other-exec-name',
            'persistentFlags:',
            '  -q, --quiet: Suppress all cli output. Is overridden by  -v, --verbose.',
            '  -v, --verbose: Prints additional information useful for development. Overrides --q, --quiet.',
            'commands:',
            '  - name: completion',
            '    flags:',
            '      -t, --target=!: The target tool format',
            '      -e, --exec-name=: Override the name of the executable',
            '      -f, --file=: Write the specification to a file instead of stdout',
            '    completion:',
            '      flag:',
            '        target: ["completely", "carapace"]',
            r'        file: ["$files"]',
          ]));
      await expectLater(spec.validate(), completes);
    });
  });
}
