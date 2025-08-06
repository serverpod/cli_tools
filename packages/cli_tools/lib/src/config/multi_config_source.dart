import 'config_source_provider.dart';
import 'configuration.dart';
import 'configuration_broker.dart';
import 'options.dart';

/// A [ConfigurationBroker] that combines configuration sources
/// from multiple providers, called configuration *domains*.
///
/// Each configuration value is identified by a *qualified key*.
/// The first domain that matches the qualified key is used to retrieve the value.
/// This means that the order of the domains is significant if the
/// matching patterns overlap.
///
/// Domains are matched using [Pattern], e.g. string prefixes or regular expressions.
///
/// ### Regex domains
/// {@template multi_domain_config_broker.regex}
/// When using regular expressions to identify the domain, the value key is derived from
/// the qualified key depending on the capturing groups in the regex.
///
/// - If the regex has no capturing groups:
///   - If the regex matches a shorter string than the qualified key, the value key is the remainder after the match.\
///     This makes prefix matching simple.
///   - If the regex matches the entire qualified key, the value key is the entire qualified key.\
///     This can be used for specific syntaxes like URLs.
///
/// - If the regex has one or more capturing groups:\
///   The value key is the string captured by the first group.
/// {@endtemplate}
class MultiDomainConfigBroker<O extends OptionDefinition>
    implements ConfigurationBroker<O> {
  final Map<Pattern, ConfigSourceProvider<O>> _configSourceProviders;

  /// Creates a [MultiDomainConfigBroker] with the given
  /// configuration source providers, each identified by matching the
  /// qualified key against a [Pattern].
  MultiDomainConfigBroker._(this._configSourceProviders);

  /// Creates a [MultiDomainConfigBroker] with the given
  /// configuration source providers, each identified by matching the
  /// qualified key against a [RegExp].
  ///
  /// {@macro multi_domain_config_broker.regex}
  MultiDomainConfigBroker.regex(
    final Map<String, ConfigSourceProvider<O>> regexDomains,
  ) : this._({
          for (final entry in regexDomains.entries)
            RegExp(entry.key): entry.value,
        });

  /// Creates a [MultiDomainConfigBroker] from a map with domain prefixes as keys.
  /// Each configuration value will be identified by a qualified key,
  /// which consists of a domain name and a value key separated by a colon.
  ///
  /// E.g. `myapp:my_setting_name`
  ///
  /// The domain prefixes must not contain colons, and it is recommended
  /// to only use lowercase letters, numbers, and underscores.
  MultiDomainConfigBroker.prefix(
    final Map<String, ConfigSourceProvider<O>> prefixDomains,
  ) : this._({
          for (final entry in prefixDomains.entries)
            '${entry.key}:': entry.value,
        });

  @override
  Object? valueOrNull(
    final String qualifiedKey,
    final Configuration<O> cfg,
  ) {
    final matchingProvider = _configSourceProviders.entries
        .map(
          (final entry) => (entry, entry.key.matchAsPrefix(qualifiedKey)),
        )
        .firstWhere(
          (final matches) => matches.$2 != null,
          orElse: () => throw StateError(
              'No matching configuration domain for key: $qualifiedKey'),
        );

    final configSource = matchingProvider.$1.value.getConfigSource(cfg);
    final match = matchingProvider.$2!;

    final String valueKey;
    if (match.groupCount > 0) {
      valueKey = match.group(1)!;
    } else {
      if (match.end < qualifiedKey.length) {
        valueKey = qualifiedKey.substring(match.end);
      } else {
        valueKey = qualifiedKey;
      }
    }

    return configSource.valueOrNull(valueKey);
  }
}
