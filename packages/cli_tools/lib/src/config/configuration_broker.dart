import 'configuration.dart';
import 'options.dart';

/// Resolves configuration values dynamically
/// and possibly from multiple sources.
abstract interface class ConfigurationBroker<O extends OptionDefinition> {
  /// Returns the value for the given key, or `null` if the key is not found
  /// or has no value.
  ///
  /// Resolution may depend on the value of other options, accessed via [cfg].
  Object? valueOrNull(final String key, final Configuration<O> cfg);
}
