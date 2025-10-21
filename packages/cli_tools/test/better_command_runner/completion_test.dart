import 'package:cli_tools/better_command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  test(
      'Given a BetterCommandRunner without enabling completion feature'
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

  group('Given a BetterCommandRunner with completion feature enabled', () {
    final infos = <String>[];
    final messageOutput = MessageOutput(
      usageLogger: (final u) => infos.add(u),
    );

    final runner = BetterCommandRunner(
      'test',
      'test project',
      messageOutput: messageOutput,
      enableCompletionCommand: true,
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
          'Command line completion commands',
        ]),
      );
    });

    test(
        'when running subcommand "completion generate -t completely -f <file>" '
        'then a proper completely specification is written to the file',
        () async {
      await d.dir('test-dir').create();
      final filePath = p.join(d.sandbox, 'test-dir', 'test.yaml');

      await runner.run([
        'completion',
        'generate',
        '-t',
        'completely',
        '-f',
        filePath,
      ]);

      final spec = d.file(
          filePath,
          stringContainsInOrder([
            'test:',
            '  - completion',
            '  - --quiet',
            '  - -q',
            '  - --verbose',
            '  - -v',
            'test completion generate*--tool:',
            '  - completely',
            '  - carapace',
            'test completion generate*-t:',
            '  - completely',
            '  - carapace',
            'test completion generate*--file:',
            '  - <file>',
            'test completion generate*-f:',
            '  - <file>',
          ]));
      await expectLater(spec.validate(), completes);
    });

    test(
        'when running subcommand "completion generate -t completely -e other-exec-name -f <file>" '
        'then the completely specification contains other-exec-name', () async {
      await d.dir('test-dir').create();
      final filePath = p.join(d.sandbox, 'test-dir', 'test.yaml');

      await runner.run([
        'completion',
        'generate',
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
            'other-exec-name completion generate*--tool:',
          ]));
      await expectLater(spec.validate(), completes);
    });

    test(
        'when running subcommand "completion generate -t carapace -f <file>" '
        'then a proper carapace specification is written to the file',
        () async {
      await d.dir('test-dir').create();
      final filePath = p.join(d.sandbox, 'test-dir', 'test.yaml');

      await runner.run([
        'completion',
        'generate',
        '-t',
        'carapace',
        '-f',
        filePath,
      ]);

      final spec = d.file(
          filePath,
          stringContainsInOrder([
            r'# yaml-language-server: $schema=https://carapace.sh/schemas/command.json',
            'name: test',
            'persistentFlags:',
            '  -q, --quiet: "Suppress all cli output. Is overridden by  -v, --verbose."',
            '  -v, --verbose: "Prints additional information useful for development. Overrides --q, --quiet."',
            'commands:',
            '  - name: completion',
            '    commands:',
            '      - name: generate',
            '      flags:',
            '        -t, --tool=!: "The completion tool to target"',
            '        -e, --exec-name=: "Override the name of the executable"',
            '        -f, --file=: "Write the specification to a file instead of stdout"',
            '      completion:',
            '        flag:',
            '          tool: ["completely", "carapace"]',
            r'          file: ["$files"]',
          ]));
      await expectLater(spec.validate(), completes);
    });

    test(
        'when running subcommand "completion generate -t carapace -e other-exec-name -f <file>" '
        'then the carapace specification contains other-exec-name', () async {
      await d.dir('test-dir').create();
      final filePath = p.join(d.sandbox, 'test-dir', 'test.yaml');

      await runner.run([
        'completion',
        'generate',
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
          ]));
      await expectLater(spec.validate(), completes);
    });

    test(
        'when running subcommand "completion embed -t completely" '
        'then the proper embedded script dart file is written', () async {
      await d.dir('test-dir', [
        d.file('test.bash', r'''
# example completion                                       -*- shell-script -*-

# This bash completions script was generated by
# completely (https://github.com/bashly-framework/completely)
# Modifying it manually is not recommended

_example_completions_filter() {
}
        ''')
      ]).create();
      final dirPath = p.join(d.sandbox, 'test-dir');
      final bashFilePath = p.join(dirPath, 'test.bash');

      await runner.run([
        'completion',
        'embed',
        '-t',
        'completely',
        '-f',
        bashFilePath,
        '-d',
        dirPath,
      ]);

      final filePath = p.join(dirPath, 'completion_script_completely.dart');
      final spec = d.file(
          filePath,
          stringContainsInOrder([
            '/// This file is auto-generated.',
            'library;',
            "import 'package:cli_tools/better_command_runner.dart' show CompletionTool;",
            'const String _completionScript = r',
            r'''
# example completion                                       -*- shell-script -*-

# This bash completions script was generated by
# completely (https://github.com/bashly-framework/completely)
# Modifying it manually is not recommended

_example_completions_filter() {
}
''',
            r'''
/// Embedded script for command line completion for `completely`.
const completionScriptCompletely = (
  tool: CompletionTool.completely,
  script: _completionScript,
);
''',
          ]));
      await expectLater(spec.validate(), completes);
    });

    test(
        'when running subcommand "completion embed -t carapace" '
        'then the proper embedded script dart file is written', () async {
      await d.dir('test-dir', [
        d.file('test.yaml', r'''
# yaml-language-server: $schema=https://carapace.sh/schemas/command.json
name: test
persistentFlags:
  -q, --quiet: Suppress all cli output. Is overridden by  -v, --verbose.
  -v, --verbose: Prints additional information useful for development. Overrides --q, --quiet.
        ''')
      ]).create();
      final dirPath = p.join(d.sandbox, 'test-dir');
      final yamlFilePath = p.join(dirPath, 'test.yaml');

      await runner.run([
        'completion',
        'embed',
        '-t',
        'carapace',
        '-f',
        yamlFilePath,
        '-d',
        dirPath,
      ]);

      final filePath = p.join(dirPath, 'completion_script_carapace.dart');
      final spec = d.file(
          filePath,
          stringContainsInOrder([
            '/// This file is auto-generated.',
            'library;',
            "import 'package:cli_tools/better_command_runner.dart' show CompletionTool;",
            'const String _completionScript = r',
            r'''
# yaml-language-server: $schema=https://carapace.sh/schemas/command.json
name: test
persistentFlags:
  -q, --quiet: Suppress all cli output. Is overridden by  -v, --verbose.
  -v, --verbose: Prints additional information useful for development. Overrides --q, --quiet.
''',
            r'''
/// Embedded script for command line completion for `carapace`.
const completionScriptCarapace = (
  tool: CompletionTool.carapace,
  script: _completionScript,
);
''',
          ]));
      await expectLater(spec.validate(), completes);
    });
  });

  group(
      'Given a BetterCommandRunner with completion feature enabled'
      ' and embedded completions', () {
    final infos = <String>[];
    final messageOutput = MessageOutput(
      usageLogger: (final u) => infos.add(u),
    );

    const completelyCompletionScript = r'''
# example completion                                       -*- shell-script -*-

# This bash completions script was generated by
# completely (https://github.com/bashly-framework/completely)
# Modifying it manually is not recommended

_example_completions_filter() {
}
''';
    const carapaceCompletionScript = r'''
# yaml-language-server: $schema=https://carapace.sh/schemas/command.json
name: test
persistentFlags:
  -q, --quiet: Suppress all cli output. Is overridden by  -v, --verbose.
  -v, --verbose: Prints additional information useful for development. Overrides --q, --quiet.
''';
    const completionScriptCompletely = (
      tool: CompletionTool.completely,
      script: completelyCompletionScript,
    );
    const completionScriptCarapace = (
      tool: CompletionTool.carapace,
      script: carapaceCompletionScript,
    );

    final runner = BetterCommandRunner(
      'test',
      'test project',
      messageOutput: messageOutput,
      enableCompletionCommand: true,
      embeddedCompletions: [
        completionScriptCompletely,
        completionScriptCarapace,
      ],
    );

    setUp(() {
      infos.clear();
    });

    test(
        'when running subcommand "completion install -t completely -d <dir>" '
        'then the proper script file is written', () async {
      await d.dir('test-dir').create();
      final dirPath = p.join(d.sandbox, 'test-dir');

      await runner.run([
        'completion',
        'install',
        '-t',
        'completely',
        '-d',
        dirPath,
      ]);

      final filePath = p.join(dirPath, 'test.bash');
      final spec = d.file(
          filePath,
          stringContainsInOrder([
            r'''
# example completion                                       -*- shell-script -*-

# This bash completions script was generated by
# completely (https://github.com/bashly-framework/completely)
# Modifying it manually is not recommended

_example_completions_filter() {
}
''',
          ]));
      await expectLater(spec.validate(), completes);
    });

    test(
        'when running subcommand "completion install -t carapace -d <dir>" '
        'then the proper script file is written', () async {
      await d.dir('test-dir').create();
      final dirPath = p.join(d.sandbox, 'test-dir');

      await runner.run([
        'completion',
        'install',
        '-t',
        'carapace',
        '-d',
        dirPath,
      ]);

      final filePath = p.join(dirPath, 'test.yaml');
      final spec = d.file(
          filePath,
          stringContainsInOrder([
            r'''
# yaml-language-server: $schema=https://carapace.sh/schemas/command.json
name: test
persistentFlags:
  -q, --quiet: Suppress all cli output. Is overridden by  -v, --verbose.
  -v, --verbose: Prints additional information useful for development. Overrides --q, --quiet.
''',
          ]));
      await expectLater(spec.validate(), completes);
    });
  });
}
