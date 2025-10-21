import 'dart:io' show File;

import 'package:config/config.dart' show ConfigurationParser;
import 'package:test/test.dart';

void main() => _runTests();

enum _Fact { correct, wrong }

enum _AllowedFile { json, yaml }

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

const _mockExtensions = {
  _AllowedFile.json: [
    'json',
    'jsoN',
    'jsOn',
    'jsON',
    'jSon',
    'jSoN',
    'jSOn',
    'jSON',
    'Json',
    'JsoN',
    'JsOn',
    'JsON',
    'JSon',
    'JSoN',
    'JSOn',
    'JSON',
  ],
  _AllowedFile.yaml: [
    'yaml',
    'yamL',
    'yaMl',
    'yaML',
    'yAml',
    'yAmL',
    'yAMl',
    'yAML',
    'Yaml',
    'YamL',
    'YaMl',
    'YaML',
    'YAml',
    'YAmL',
    'YAMl',
    'YAML',
    'yml',
    'ymL',
    'yMl',
    'yML',
    'Yml',
    'YmL',
    'YMl',
    'YML',
  ],
};

const _anUnsupportedExtension = 'txt';

final _mockDir = './test_tmp_${DateTime.now().millisecondsSinceEpoch}';
final _aNonExistentFilename = 'xyz_${DateTime.now().millisecondsSinceEpoch}';

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
          ..createSync(recursive: true, exclusive: false)
          ..writeAsStringSync(_mockContent[fileFormat]![fact]!);
      }
      File(_buildFilepath(fileFormat, fact, _anUnsupportedExtension))
        ..createSync(recursive: true, exclusive: false)
        ..writeAsStringSync(_mockContent[fileFormat]![fact]!);
    }
  });
}

void _cleanupMockFiles() => File(_mockDir).deleteSync(recursive: true);

void _runTests() {
  setUpAll(() => _prepareMockFiles());
  tearDownAll(() => _cleanupMockFiles());

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
