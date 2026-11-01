import 'dart:async' show FutureOr;
import 'dart:io' show Directory, File;

import 'package:config/config.dart';
import 'package:test/test.dart';

enum Color { red, green, blue }

class ServerOption extends StringOption {
  const ServerOption({super.argName});

  @override
  FutureOr<CompletionResult> complete(final CompletionContext context) async {
    await Future<void>.delayed(Duration.zero);
    return CompletionResult.strings(['alpha', 'beta'], noSpace: true);
  }
}

const _context = CompletionContext(
  wordToComplete: '',
  precedingWords: [],
  commands: [],
  parsedArgs: _NoParsedArgs(),
  environment: {},
);

class _NoParsedArgs implements ParsedArgs {
  const _NoParsedArgs();

  @override
  bool wasParsed(final ConfigOptionBase option) => false;

  @override
  bool flag(final FlagOption option) => throw StateError('not parsed');

  @override
  String option(final ConfigOptionBase option) =>
      throw StateError('not parsed');

  @override
  List<String> multiOption(final MultiOption option) =>
      throw StateError('not parsed');

  @override
  List<String> get rest => const [];

  @override
  List<String> get parseErrors => const [];
}

Future<CompletionResult> complete(final OptionDefinition option) async {
  return option.option.complete(_context);
}

void main() {
  group('Given a StringOption without allowed values', () {
    const option = StringOption(argName: 'name');

    test('when completing then native file completion is requested', () async {
      final result = await complete(option);
      expect(result.pathMode, CompletionPathMode.files);
      expect(result.candidates, isEmpty);
    });
  });

  group('Given a StringOption with allowed values and allowed help', () {
    const option = StringOption(
      argName: 'name',
      allowedValues: ['a', 'b'],
      allowedHelp: {'a': 'The A', 'b': 'The B'},
    );

    test('when completing then the allowed values are offered '
        'with their help as description', () async {
      final result = await complete(option);
      expect(result.pathMode, CompletionPathMode.none);
      expect(result.candidates, [
        const CompletionCandidate('a', description: 'The A'),
        const CompletionCandidate('b', description: 'The B'),
      ]);
    });
  });

  group('Given an IntOption with allowed help only', () {
    const option = IntOption(
      argName: 'size',
      allowedHelp: {'1024': '1KB', '2048': '2KB'},
    );

    test('when completing then the allowed help keys are offered', () async {
      final result = await complete(option);
      expect(result.candidates, [
        const CompletionCandidate('1024', description: '1KB'),
        const CompletionCandidate('2048', description: '2KB'),
      ]);
    });
  });

  group('Given an IntOption with allowed values', () {
    const option = IntOption(argName: 'size', allowedValues: [1, 2]);

    test('when completing then the formatted values are offered', () async {
      final result = await complete(option);
      expect(result.candidates.map((final c) => c.value), ['1', '2']);
    });
  });

  group('Given an EnumOption', () {
    const option = EnumOption(
      enumParser: EnumParser(Color.values),
      argName: 'color',
      allowedHelp: {'red': 'Like roses'},
    );

    test('when completing then all enum names are offered, '
        'described by allowed help when present', () async {
      final result = await complete(option);
      expect(result.candidates, [
        const CompletionCandidate('red', description: 'Like roses'),
        const CompletionCandidate('green'),
        const CompletionCandidate('blue'),
      ]);
    });

    test('when completing an option restricted by allowed values '
        'then only those enum names are offered', () async {
      const restricted = EnumOption(
        enumParser: EnumParser(Color.values),
        argName: 'color',
        allowedValues: [Color.green, Color.blue],
      );
      final result = await complete(restricted);
      expect(result.candidates.map((final c) => c.value), ['green', 'blue']);
    });
  });

  group('Given a FlagOption', () {
    const option = FlagOption(argName: 'force');

    test('when completing then nothing is offered', () async {
      final result = await complete(option);
      expect(result.candidates, isEmpty);
      expect(result.pathMode, CompletionPathMode.none);
    });
  });

  group('Given a MultiStringOption', () {
    test('when completing with allowed values '
        'then the allowed element values are offered', () async {
      const option = MultiStringOption(
        argName: 'tags',
        allowedValues: ['x', 'y'],
        allowedHelp: {'x': 'The X'},
      );
      final result = await complete(option);
      expect(result.candidates, [
        const CompletionCandidate('x', description: 'The X'),
        const CompletionCandidate('y'),
      ]);
    });

    test('when completing without allowed values '
        'then native file completion is requested', () async {
      const option = MultiStringOption(argName: 'tags');
      final result = await complete(option);
      expect(result.pathMode, CompletionPathMode.files);
    });
  });

  group('Given file system options', () {
    test('when completing a DirOption '
        'then native directory completion is requested', () async {
      const option = DirOption(argName: 'dir');
      final result = await complete(option);
      expect(result.pathMode, CompletionPathMode.directories);
    });

    test('when completing a FileOption '
        'then native file completion is requested', () async {
      const option = FileOption(argName: 'file');
      final result = await complete(option);
      expect(result.pathMode, CompletionPathMode.files);
    });

    test('when completing a DirOption with a default value '
        'then the default does not affect the completion', () async {
      final option = DirOption(argName: 'dir', defaultsTo: Directory('x'));
      final result = await complete(option);
      expect(result.pathMode, CompletionPathMode.directories);
      expect(File('x').existsSync(), isFalse);
    });
  });

  group('Given a custom option type overriding complete', () {
    const option = ServerOption(argName: 'server');

    test('when completing then its asynchronous result is used', () async {
      final result = await complete(option);
      expect(result.candidates.map((final c) => c.value), ['alpha', 'beta']);
      expect(result.noSpace, isTrue);
    });
  });

  group('Given a CompletionResult', () {
    test('when created for files with extensions '
        'then the extensions are kept without the path mode changing', () {
      const result = CompletionResult.files(extensions: ['yaml', 'json']);
      expect(result.pathMode, CompletionPathMode.files);
      expect(result.fileExtensions, ['yaml', 'json']);
      expect(result.candidates, isEmpty);
    });

    test('when created as none then nothing is offered', () {
      const result = CompletionResult.none();
      expect(result.pathMode, CompletionPathMode.none);
      expect(result.candidates, isEmpty);
    });
  });
}
