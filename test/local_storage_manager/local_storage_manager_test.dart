import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:cli_tools/src/local_storage_manager/local_storage_manager_exceptions.dart';
import 'package:cli_tools/src/local_storage_manager/local_storage_manager.dart';

void main() {
  var tempDir = Directory.systemTemp.createTempSync();
  var localStoragePath = tempDir.path;

  tearDown(() {
    tempDir.listSync().forEach((file) => file.deleteSync());
  });

  test('Given an existing file '
      'when calling removeFile '
      'then the file is deleted successfully', () async {
    var fileName = 'test.json';
    var file = File(p.join(localStoragePath, fileName));
    file.createSync();

    await LocalStorageManager.removeFile(
      fileName: fileName,
      localStoragePath: localStoragePath,
    );

    expect(file.existsSync(), isFalse);
  });

  test('Given a non-existing file '
      'when calling removeFile '
      'then no exception is thrown', () async {
    var fileName = 'nonexistent.json';

    expect(
      () => LocalStorageManager.removeFile(
        fileName: fileName,
        localStoragePath: localStoragePath,
      ),
      returnsNormally,
    );
  });

  test('Given a valid json object '
      'when calling storeJsonFile '
      'then the file is created with correct content', () async {
    var fileName = 'test.json';
    var json = {'key': 'value'};

    await LocalStorageManager.storeJsonFile(
      fileName: fileName,
      json: json,
      localStoragePath: localStoragePath,
    );

    var file = File(p.join(localStoragePath, fileName));
    expect(file.existsSync(), isTrue);
    expect(file.readAsStringSync(), '{\n  "key": "value"\n}');
  });

  test('Given a json object with non compatible values '
      'when calling storeJsonFile '
      'then it throws SerializationException', () async {
    var fileName = 'test.json';
    var invalidJson = {'key': Object()}; // Non-serializable value.

    expect(
      () => LocalStorageManager.storeJsonFile(
        fileName: fileName,
        json: invalidJson,
        localStoragePath: localStoragePath,
      ),
      throwsA(isA<SerializationException>()),
    );
  });

  test('Given an existing json file '
      'when calling tryFetchAndDeserializeJsonFile '
      'then it returns the deserialized object', () async {
    var fileName = 'test.json';
    var fileContent = '{"key": "value"}';
    var file = File(p.join(localStoragePath, fileName));
    file.writeAsStringSync(fileContent);

    var result = await LocalStorageManager.tryFetchAndDeserializeJsonFile<
      Map<String, dynamic>
    >(
      fileName: fileName,
      localStoragePath: localStoragePath,
      fromJson: (json) => json,
    );

    expect(result, {'key': 'value'});
  });

  test('Given a missing json file '
      'when calling tryFetchAndDeserializeJsonFile '
      'then it returns null', () async {
    var fileName = 'nonexistent.json';

    var result = await LocalStorageManager.tryFetchAndDeserializeJsonFile<
      Map<String, dynamic>
    >(
      fileName: fileName,
      localStoragePath: localStoragePath,
      fromJson: (json) => json,
    );

    expect(result, isNull);
  });

  test('Given a malformed json file '
      'when calling tryFetchAndDeserializeJsonFile '
      'then it throws DeserializationException', () async {
    var fileName = 'invalid.json';
    var malformedJson = '{"key": "value"';
    var file = File(p.join(localStoragePath, fileName));
    file.writeAsStringSync(malformedJson);

    expect(
      () => LocalStorageManager.tryFetchAndDeserializeJsonFile<
        Map<String, dynamic>
      >(
        fileName: fileName,
        localStoragePath: localStoragePath,
        fromJson: (json) => json,
      ),
      throwsA(isA<DeserializationException>()),
    );
  });

  test('Given a corrupt file '
      'when calling tryFetchAndDeserializeJsonFile '
      'then it throws ReadException', () async {
    var fileName = 'invalid.json';
    var file = File(p.join(localStoragePath, fileName));
    file.writeAsBytesSync([0xC3, 0x28]);

    expect(
      () => LocalStorageManager.tryFetchAndDeserializeJsonFile<
        Map<String, dynamic>
      >(
        fileName: fileName,
        localStoragePath: localStoragePath,
        fromJson: (json) => json,
      ),
      throwsA(isA<ReadException>()),
    );
  });
}
