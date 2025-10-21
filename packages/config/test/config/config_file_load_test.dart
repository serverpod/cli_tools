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
    'yml',
    'ymL',
    'yMl',
    'yML',
    'Yml',
    'YmL',
    'YMl',
    'YML',
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
  ],
};

const _anUnsupportedExtension = 'txt';

final _mockDir = './test_tmp_${DateTime.now().millisecondsSinceEpoch}';
final _aNonExistentFilename = 'xyz_${DateTime.now().millisecondsSinceEpoch}';

String _buildFilepath(
  final _Fact fact,
  final _AllowedFile format,
  final String extension,
) =>
    '$_mockDir/${_mockFilenames[format]![fact]!}.$extension';

void _prepareMockFiles() {
  _mockFilenames.forEach((final fileFormat, final namesMap) {
    for (final fact in _Fact.values) {
      for (final fileExtension in _mockExtensions[fileFormat]!) {
        File(_buildFilepath(fact, fileFormat, fileExtension))
          ..createSync(recursive: true, exclusive: false)
          ..writeAsStringSync(_mockContent[fileFormat]![fact]!);
      }
      File(_buildFilepath(fact, fileFormat, _anUnsupportedExtension))
        ..createSync(recursive: true, exclusive: false)
        ..writeAsStringSync(_mockContent[fileFormat]![fact]!);
    }
  });
}

void _cleanupMockFiles() => File(_mockDir).deleteSync(recursive: true);

void _runTests() {
  setUpAll(() => _prepareMockFiles());
  tearDownAll(() => _cleanupMockFiles());

  group('Given correct file content', () {
    group('with a supported file extension', () {
      group('when loading a JSON file', () {
        test('then it is parsed successfully', () {
          for (final jsonExtension in _mockExtensions[_AllowedFile.json]!) {
            expect(
              ConfigurationParser.fromFile(_buildFilepath(
                _Fact.correct,
                _AllowedFile.json,
                jsonExtension,
              )).valueOrNull(_mockKey),
              equals(_mockVal),
            );
          }
        });
      });
      group('when loading a YAML file', () {
        test('then it is parsed successfully', () {
          for (final yamlExtension in _mockExtensions[_AllowedFile.yaml]!) {
            expect(
              ConfigurationParser.fromFile(_buildFilepath(
                _Fact.correct,
                _AllowedFile.yaml,
                yamlExtension,
              )).valueOrNull(_mockKey),
              equals(_mockVal),
            );
          }
        });
      });
    });
    group('with an unsupported file extension', () {
      group('when loading a JSON file', () {
        test('then it reports an Unsupported Error', () {
          expect(
            () => ConfigurationParser.fromFile(_buildFilepath(
              _Fact.correct,
              _AllowedFile.json,
              _anUnsupportedExtension,
            )),
            throwsUnsupportedError,
          );
        });
      });
      group('when loading a YAML file', () {
        test('then it reports an Unsupported Error', () {
          expect(
            () => ConfigurationParser.fromFile(_buildFilepath(
              _Fact.correct,
              _AllowedFile.yaml,
              _anUnsupportedExtension,
            )),
            throwsUnsupportedError,
          );
        });
      });
    });
  });

  group('Given wrong file content', () {
    group('with a supported file extension', () {
      group('when loading a JSON file', () {
        test('then it reports a Format Exception', () {
          for (final jsonExtension in _mockExtensions[_AllowedFile.json]!) {
            expect(
              () => ConfigurationParser.fromFile(_buildFilepath(
                _Fact.wrong,
                _AllowedFile.json,
                jsonExtension,
              )),
              throwsFormatException,
            );
          }
        });
      });
      group('when loading a YAML file', () {
        test('then it reports a Format Exception', () {
          for (final yamlExtension in _mockExtensions[_AllowedFile.yaml]!) {
            expect(
              () => ConfigurationParser.fromFile(_buildFilepath(
                _Fact.wrong,
                _AllowedFile.yaml,
                yamlExtension,
              )),
              throwsFormatException,
            );
          }
        });
      });
    });
    group('with an unsupported file extension', () {
      group('when loading a JSON file', () {
        test('then it reports an Unsupported Error', () {
          expect(
            () => ConfigurationParser.fromFile(_buildFilepath(
              _Fact.wrong,
              _AllowedFile.json,
              _anUnsupportedExtension,
            )),
            throwsUnsupportedError,
          );
        });
      });
      group('when loading a YAML file', () {
        test('then it reports an Unsupported Error', () {
          expect(
            () => ConfigurationParser.fromFile(_buildFilepath(
              _Fact.wrong,
              _AllowedFile.yaml,
              _anUnsupportedExtension,
            )),
            throwsUnsupportedError,
          );
        });
      });
    });
  });

  group('Given a non-existent file', () {
    group('with a supported file extension', () {
      group('when attempting to load a JSON file', () {
        test('then it reports an Argument Error', () {
          for (final jsonExtension in _mockExtensions[_AllowedFile.json]!) {
            expect(
              () => ConfigurationParser.fromFile(
                '$_aNonExistentFilename.$jsonExtension',
              ),
              throwsArgumentError,
            );
          }
        });
      });
      group('when attempting to load a YAML file', () {
        test('then it reports an Argument Error', () {
          for (final yamlExtension in _mockExtensions[_AllowedFile.yaml]!) {
            expect(
              () => ConfigurationParser.fromFile(
                '$_aNonExistentFilename.$yamlExtension',
              ),
              throwsArgumentError,
            );
          }
        });
      });
    });
    group('with an unsupported file extension', () {
      group('when attempting to load any file', () {
        test('then it reports an Unsupported Error', () {
          expect(
            () => ConfigurationParser.fromFile(
              '$_aNonExistentFilename.$_anUnsupportedExtension',
            ),
            throwsUnsupportedError,
          );
        });
      });
    });
  });
}
