import 'config_source.dart';
import 'configuration.dart';
import 'configuration_parser.dart';
import 'options.dart';

/// Provider of a [ConfigurationSource] that is dynamically
/// based on the current configuration.
///
/// It is lazily invoked and should cache the [ConfigurationSource].
abstract class ConfigSourceProvider<O extends OptionDefinition> {
  /// Get the [ConfigurationSource] given the current configuration.
  /// This is lazily invoked and should cache the [ConfigurationSource]
  /// for subsequent invocations.
  ConfigurationSource getConfigSource(final Configuration<O> cfg);
}

/// A [ConfigSourceProvider] that uses the value of an option
/// as data source.
class OptionContentConfigProvider<O extends OptionDefinition<String>>
    extends ConfigSourceProvider<O> {
  final O contentOption;
  final ConfigEncoding format;
  ConfigurationSource? _configProvider;

  OptionContentConfigProvider({
    required this.contentOption,
    required this.format,
  });

  @override
  ConfigurationSource getConfigSource(final Configuration<O> cfg) {
    var provider = _configProvider;
    if (provider == null) {
      final optionValue = cfg.optionalValue(contentOption) ?? '';
      provider = ConfigurationParser.fromString(
        optionValue,
        format: format,
      );
      _configProvider = provider;
    }
    return provider;
  }
}
