/// A source of configuration values.
///
/// {@template config_source.valueOrNull}
/// Returns the value for the given key, or `null` if the key is not found
/// or has no value.
/// {@endtemplate}
abstract interface class ConfigurationSource {
  /// {@macro config_source.valueOrNull}
  Object? valueOrNull(final String key);
}

/// Simple [ConfigurationSource] adapter for a [Map<String, String>].
class MapConfigSource implements ConfigurationSource {
  final Map<String, String> entries;

  MapConfigSource(this.entries);

  @override
  String? valueOrNull(final String key) {
    return entries[key];
  }
}
