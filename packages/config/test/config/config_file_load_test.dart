import 'dart:io' show File;
import 'dart:math' show pow;

import 'package:config/config.dart' show ConfigurationParser;
import 'package:test/test.dart';

void main() => _runTests();

enum _Fact { correct, wrong }

enum _AllowedFile {
  json,
  yaml;

  static const extensions = {
    json: {'json'},
    yaml: {'yaml', 'yml'}
  };
}

const _mockContent = {
  _AllowedFile.json: {
    _Fact.correct: '{"mock-key": "mock val"}',
    _Fact.wrong: '{"mock-key": mock val}',
  },
  _AllowedFile.yaml: {
    _Fact.correct: 'mock-key: "mock val"',
    _Fact.wrong: 'mock-key: mock val key2: value2',
  },
};

const _mockKey = '/mock-key';
const _mockVal = 'mock val';

const _mockFilenames = {
  _AllowedFile.json: {
    _Fact.correct: 'mock_correct_json_file',
    _Fact.wrong: 'mock_wrong_json_file',
  },
  _AllowedFile.yaml: {
    _Fact.correct: 'mock_correct_yaml_file',
    _Fact.wrong: 'mock_wrong_yaml_file',
  },
};

const _anUnsupportedExtension = 'txt';

final _mockExtensions = {
  _AllowedFile.json: [
    for (final fileExtension in _AllowedFile.extensions[_AllowedFile.json]!)
      ..._generateCaseInsensitive(fileExtension)
  ],
  _AllowedFile.yaml: [
    for (final fileExtension in _AllowedFile.extensions[_AllowedFile.yaml]!)
      ..._generateCaseInsensitive(fileExtension)
  ],
};

final _mockDir = './test_tmp_${DateTime.now().millisecondsSinceEpoch}';
final _aNonExistentFilename = 'xyz_${DateTime.now().millisecondsSinceEpoch}';

void _verifyMockFileExtensions() {
  final jsonExtensionSamplesCount = _mockExtensions[_AllowedFile.json]!.length;
  final yamlExtensionSamplesCount = _mockExtensions[_AllowedFile.yaml]!.length;
  assert(
    jsonExtensionSamplesCount ==
        Set<String>.from(_mockExtensions[_AllowedFile.json]!).length,
    'JSON extension samples must be unique.',
  );
  assert(
    jsonExtensionSamplesCount ==
        _AllowedFile.extensions[_AllowedFile.json]!.fold<num>(
            0, (final prev, final curr) => prev + pow(2, curr.length)),
    'JSON extension samples must be mathematically sound.',
  );
  assert(
    yamlExtensionSamplesCount ==
        Set<String>.from(_mockExtensions[_AllowedFile.yaml]!).length,
    'YAML extension samples must be unique.',
  );
  assert(
    yamlExtensionSamplesCount ==
        _AllowedFile.extensions[_AllowedFile.yaml]!.fold<num>(
            0, (final prev, final curr) => prev + pow(2, curr.length)),
    'YAML extension samples must be mathematically sound.',
  );
  // print('Unique JSON extensions for testing: $jsonExtensionSamplesCount');
  // print('Unique YAML extensions for testing: $yamlExtensionSamplesCount');
}

String _buildFilepath(
  final _AllowedFile format,
  final _Fact fact,
  final String extension,
) =>
    '$_mockDir/${_mockFilenames[format]![fact]!}.$extension';

void _prepareMockFiles() {
  _mockFilenames.forEach((final fileFormat, final namesMap) {
    for (final fact in _Fact.values) {
      for (final fileExtension in _mockExtensions[fileFormat]!) {
        File(_buildFilepath(fileFormat, fact, fileExtension))
          ..createSync(recursive: true, exclusive: true)
          ..writeAsStringSync(_mockContent[fileFormat]![fact]!);
      }
      File(_buildFilepath(fileFormat, fact, _anUnsupportedExtension))
        ..createSync(recursive: true, exclusive: true)
        ..writeAsStringSync(_mockContent[fileFormat]![fact]!);
    }
  });
}

void _cleanupMockFiles() => File(_mockDir).deleteSync(recursive: true);

String? _toggleCase(final String ch) {
  if (ch.length != 1) {
    throw ArgumentError;
  }
  final uppercaseCh = ch.toUpperCase();
  final lowercaseCh = ch.toLowerCase();
  if (ch == uppercaseCh && ch == lowercaseCh) {
    return null;
  }
  return ch == uppercaseCh ? lowercaseCh : uppercaseCh;
}

Iterable<String> _generateCaseInsensitive(final String input) sync* {
  if (input.isEmpty) {
    yield '';
    return;
  }
  final chOriginalCase = input[0];
  final chToggledCase = _toggleCase(chOriginalCase);
  if (input.length == 1) {
    yield* [chOriginalCase, if (chToggledCase != null) chToggledCase];
    return;
  }
  for (final recursiveSample in _generateCaseInsensitive(input.substring(1))) {
    yield* [
      '$chOriginalCase$recursiveSample',
      if (chToggledCase != null) '$chToggledCase$recursiveSample'
    ];
  }
}

void _runTests() {
  setUpAll(() {
    _verifyMockFileExtensions();
    _prepareMockFiles();
  });
  tearDownAll(() {
    _cleanupMockFiles();
  });

  group('JSON files', () {
    test('with correct file content and correct extension', () {
      for (final fileExtension in _mockExtensions[_AllowedFile.json]!) {
        expect(
          ConfigurationParser.fromFile(_buildFilepath(
            _AllowedFile.json,
            _Fact.correct,
            fileExtension,
          )).valueOrNull(_mockKey),
          equals(_mockVal),
        );
      }
    });
    test('with correct file content but wrong extension', () {
      expect(
        () => ConfigurationParser.fromFile(_buildFilepath(
          _AllowedFile.json,
          _Fact.correct,
          _anUnsupportedExtension,
        )),
        throwsUnsupportedError,
      );
    });
    test('with wrong file content but correct extension', () {
      for (final fileExtension in _mockExtensions[_AllowedFile.json]!) {
        expect(
          () => ConfigurationParser.fromFile(_buildFilepath(
            _AllowedFile.json,
            _Fact.wrong,
            fileExtension,
          )),
          throwsFormatException,
        );
      }
    });
    test('with wrong file content and wrong extension', () {
      expect(
        () => ConfigurationParser.fromFile(_buildFilepath(
          _AllowedFile.json,
          _Fact.wrong,
          _anUnsupportedExtension,
        )),
        throwsUnsupportedError,
      );
    });
  });

  group('YAML files', () {
    test('with correct file content and correct extension', () {
      for (final fileExtension in _mockExtensions[_AllowedFile.yaml]!) {
        expect(
          ConfigurationParser.fromFile(_buildFilepath(
            _AllowedFile.yaml,
            _Fact.correct,
            fileExtension,
          )).valueOrNull(_mockKey),
          equals(_mockVal),
        );
      }
    });
    test('with correct file content but wrong extension', () {
      expect(
        () => ConfigurationParser.fromFile(_buildFilepath(
          _AllowedFile.yaml,
          _Fact.correct,
          _anUnsupportedExtension,
        )),
        throwsUnsupportedError,
      );
    });
    test('with wrong file content but correct extension', () {
      for (final fileExtension in _mockExtensions[_AllowedFile.yaml]!) {
        expect(
          () => ConfigurationParser.fromFile(_buildFilepath(
            _AllowedFile.yaml,
            _Fact.wrong,
            fileExtension,
          )),
          throwsFormatException,
        );
      }
    });
    test('with wrong file content and wrong extension', () {
      expect(
        () => ConfigurationParser.fromFile(_buildFilepath(
          _AllowedFile.yaml,
          _Fact.wrong,
          _anUnsupportedExtension,
        )),
        throwsUnsupportedError,
      );
    });
  });

  group('Non-existent file', () {
    test('of ".json" type', () {
      expect(
        () => ConfigurationParser.fromFile('$_aNonExistentFilename.json'),
        throwsArgumentError,
      );
    });
    test('of ".yaml" type', () {
      expect(
        () => ConfigurationParser.fromFile('$_aNonExistentFilename.yaml'),
        throwsArgumentError,
      );
    });
    test('of ".yml" type', () {
      expect(
        () => ConfigurationParser.fromFile('$_aNonExistentFilename.yml'),
        throwsArgumentError,
      );
    });
    test('of unsupported type', () {
      expect(
        () => ConfigurationParser.fromFile(
          '$_aNonExistentFilename.$_anUnsupportedExtension',
        ),
        throwsUnsupportedError,
      );
    });
  });
}
