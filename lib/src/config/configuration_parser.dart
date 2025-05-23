import 'dart:io';

import 'config_source.dart';
import 'json_yaml_document.dart';

/// Encoding format of a configuration data source.
enum ConfigEncoding {
  json,
  yaml,
}

/// Parsers for various configuration data sources.
///
/// Produces a [ConfigurationSource] from a data source and a format.
///
/// Supports the formats in [ConfigEncoding].
abstract final class ConfigurationParser {
  /// Parses a configuration from a string.
  static ConfigurationSource fromString(
    final String source, {
    required final ConfigEncoding format,
  }) {
    switch (format) {
      case ConfigEncoding.json:
        return _JyConfigSource(JsonYamlDocument.fromJson(source));
      case ConfigEncoding.yaml:
        return _JyConfigSource(JsonYamlDocument.fromYaml(source));
    }
  }

  /// Parses a configuration from a file.
  static ConfigurationSource fromFile(
    final String filePath,
  ) {
    if (filePath.endsWith('.json')) {
      return fromString(
        _loadFile(filePath),
        format: ConfigEncoding.json,
      );
    } else if (filePath.endsWith('.yaml') || filePath.endsWith('.yml')) {
      return fromString(
        _loadFile(filePath),
        format: ConfigEncoding.yaml,
      );
    }
    throw UnsupportedError('Unsupported file extension: $filePath');
  }

  static String _loadFile(final String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw ArgumentError('File not found: $filePath');
    }
    return file.readAsStringSync();
  }
}

/// [ConfigurationSource] adapter for a [JsonYamlDocument].
class _JyConfigSource implements ConfigurationSource {
  final JsonYamlDocument _jyDocument;

  _JyConfigSource(this._jyDocument);

  @override
  Object? valueOrNull(final String pointerKey) {
    return _jyDocument.valueAtPointer(pointerKey);
  }
}
