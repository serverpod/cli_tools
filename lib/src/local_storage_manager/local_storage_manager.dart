import 'dart:convert';
import 'dart:io';

import 'package:cli_tools/src/local_storage_manager/local_storage_manager_exceptions.dart';
import 'package:path/path.dart' as p;

/// An abstract class that provides methods for storing, fetching and removing
/// json files from local storage.
///
/// Throws an [UnsupportedPlatformException] if the platform is not supported.
abstract base class LocalStorageManager {
  /// Fetches the home directory of the current user.
  static Directory get homeDirectory {
    var envVars = Platform.environment;

    if (Platform.isWindows) {
      return Directory(envVars['UserProfile']!);
    } else if (Platform.isLinux || Platform.isMacOS) {
      return Directory(envVars['HOME']!);
    }
    throw (UnsupportedPlatformException);
  }

  /// Removes a file from the local storage.
  /// If the file does not exist, nothing will happen.
  ///
  /// [fileName] The name of the file to remove.
  /// [localStoragePath] The path to the local storage directory.
  ///
  /// Throws a [DeleteException] if an error occurs during file deletion.
  static Future<void> removeFile({
    required String fileName,
    required String localStoragePath,
  }) async {
    var file = File(p.join(localStoragePath, fileName));

    if (!file.existsSync()) return;

    try {
      await file.delete();
    } catch (e, stackTrace) {
      throw DeleteException(file, e, stackTrace);
    }
  }

  /// Stores a json file in the local storage.
  /// If the file already exists it will be overwritten.
  ///
  /// [fileName] The name of the file to store.
  /// [json] The json data to store.
  /// [localStoragePath] The path to the local storage directory.
  ///
  /// Throws a [CreateException] if an error occurs during file creation.
  /// Throws a [SerializationException] if an error occurs during serialization.
  /// Throws a [WriteException] if an error occurs during file writing.
  static Future<void> storeJsonFile({
    required String fileName,
    required Map<String, dynamic> json,
    required String localStoragePath,
  }) async {
    var file = File(p.join(localStoragePath, fileName));

    if (!file.existsSync()) {
      try {
        file.createSync(recursive: true);
      } catch (e, stackTrace) {
        throw CreateException(file, e, stackTrace);
      }
    }

    String jsonString;
    try {
      jsonString = const JsonEncoder.withIndent('  ').convert(json);
    } catch (e, stackTrace) {
      throw SerializationException(json, e, stackTrace);
    }

    try {
      file.writeAsStringSync(jsonString);
    } catch (e, stackTrace) {
      throw WriteException(file, e, stackTrace);
    }
  }

  /// Tries to fetch and deserialize a json file from the local storage.
  /// If the file does not exist or if an error occurs during reading or
  /// deserialization, null will be returned.
  ///
  /// [fileName] The name of the file to fetch.
  /// [localStoragePath] The path to the local storage directory.
  /// [fromJson] A function that is used to deserialize the json data.
  ///
  /// Throws a [ReadException] if an error occurs during file reading.
  /// Throws a [DeserializationException] if an error occurs during deserialization.
  static Future<T?> tryFetchAndDeserializeJsonFile<T>({
    required String fileName,
    required String localStoragePath,
    required T Function(Map<String, dynamic> json) fromJson,
  }) async {
    var file = File(p.join(localStoragePath, fileName));

    if (!file.existsSync()) return null;

    dynamic json;
    try {
      json = jsonDecode(file.readAsStringSync());
    } catch (e, stackTrace) {
      throw ReadException(file, e, stackTrace);
    }

    try {
      return fromJson(json);
    } catch (e, stackTrace) {
      throw DeserializationException(file, e, stackTrace);
    }
  }
}
