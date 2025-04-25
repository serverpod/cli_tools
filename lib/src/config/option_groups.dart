import 'configuration.dart';
import 'option_resolution.dart';

/// An option group for mutually exclusive options.
///
/// No more than one of the options in the group can be specified.
///
/// Optionally the group can allow defaults, i.e. default values
/// are disregarded when counting the number of specified options.
///
/// Optionally the group can be made mandatory, in which case
/// one of its options must be specified.
class MutuallyExclusive extends OptionGroup {
  final bool mandatory;
  final bool allowDefaults;

  const MutuallyExclusive(
    super.name, {
    this.mandatory = false,
    this.allowDefaults = false,
  });

  @override
  String? validate(
    final Map<OptionDefinition, OptionResolution> optionResolutions,
  ) {
    final providedCount = optionResolutions.values
        .where((final r) => allowDefaults ? r.isSpecified : r.hasValue)
        .length;

    if (providedCount > 1) {
      final opts = optionResolutions.keys.map((final o) => o.option);
      return 'These options are mutually exclusive: ${opts.join(', ')}';
    }

    if (mandatory && providedCount == 0) {
      return 'Option group $name requires one of the options to be provided';
    }

    return null;
  }
}
