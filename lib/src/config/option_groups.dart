import 'exceptions.dart';
import 'option_resolution.dart';
import 'options.dart';

enum MutuallyExclusiveMode {
  noDefaults,
  allowDefaults,
  mandatory,
}

/// An option group for mutually exclusive options.
///
/// No more than one of the options in the group can be specified.
///
/// ### Mutually Exclusive Mode
///
/// These modes are supported:
///
/// - `noDefaults`: The options in the group are not allowed to have defaults.
///   This is the standard mode.
/// - `allowDefaults`: The options in the group are allowed to have defaults.
/// - `mandatory`: An option in the group is required to be explicitly set.
///   Defaults are not allowed.
///
/// Mandatory cannot be combined with allowing default values.
class MutuallyExclusive extends OptionGroup {
  final MutuallyExclusiveMode mode;

  const MutuallyExclusive(
    super.name, {
    this.mode = MutuallyExclusiveMode.noDefaults,
  });

  @override
  void validateDefinitions(
    final Iterable<OptionDefinition> options,
  ) {
    if (mode == MutuallyExclusiveMode.allowDefaults) return;

    for (final opt in options) {
      if (opt.option.defaultValue() != null) {
        throw InvalidOptionConfigurationError(
          opt,
          'Option group `$name` does not allow defaults',
        );
      }
    }
  }

  @override
  String? validateValues(
    final Map<OptionDefinition, OptionResolution> optionResolutions,
  ) {
    final allowDefaults = mode == MutuallyExclusiveMode.allowDefaults;
    final providedCount = optionResolutions.values
        .where((final r) => allowDefaults ? r.isSpecified : r.hasValue)
        .length;

    if (providedCount > 1) {
      final opts = optionResolutions.keys.map((final o) => o.option);
      return 'These options are mutually exclusive: ${opts.join(', ')}';
    }

    if (mode == MutuallyExclusiveMode.mandatory && providedCount == 0) {
      return 'Option group $name requires one of the options to be provided';
    }

    return null;
  }
}
