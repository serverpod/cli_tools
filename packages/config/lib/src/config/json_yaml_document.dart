import 'dart:convert';

import 'package:rfc_6901/rfc_6901.dart';
import 'package:yaml/yaml.dart';

/// A parsed JSON or YAML document.
///
/// {@template json_yaml_document.valueAtPointer}
/// Supports accessing values identified by JSON pointers (RFC 6901).
/// See: https://datatracker.ietf.org/doc/html/rfc6901
///
/// Example: '/foo/0/bar'
/// {@endtemplate}
class JsonYamlDocument {
  final Object? _document;

  JsonYamlDocument.fromJson(final String jsonSource)
      : _document = jsonSource.isEmpty ? null : jsonDecode(jsonSource);

  JsonYamlDocument.fromYaml(final String yamlSource)
      : _document = loadYaml(yamlSource);

  /// {@macro json_yaml_document.valueAtPointer}
  Object? valueAtPointer(final String pointerKey) {
    final pointer = JsonPointer(pointerKey);
    return pointer.read(_document, orElse: () => null);
  }
}
