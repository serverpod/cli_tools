import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:collection/collection.dart';

import 'configuration_broker.dart';
import 'exceptions.dart';
import 'options.dart';
import 'option_resolution.dart';
import 'source_type.dart';

/// A configuration object that holds the values for a set of configuration options.
class Configuration<O extends OptionDefinition> {
  final List<O> _options;
  final Map<O, OptionResolution> _config;
  final List<String> _errors;

  /// Creates a configuration with the provided option values.
  ///
  /// This does not throw upon value parsing or validation errors,
  /// instead the caller is responsible for checking if [errors] is non-empty.
  Configuration.fromValues({
    required final Map<O, Object?> values,
  }) : this.resolve(
          options: values.keys,
          presetValues: values,
        );

  /// Creates a configuration by copying the contents from another.
  ///
  /// This is a 1:1 copy including the errors.
  Configuration.from({
    required final Configuration<O> configuration,
  })  : _options = List.from(configuration._options),
        _config = Map.from(configuration._config),
        _errors = List.from(configuration._errors);

  /// Creates a configuration with option values resolved from the provided context.
  ///
  /// [argResults] is used if provided. Otherwise [args] is used if provided.
  ///
  /// If [presetValues] is provided, the values present will override the other sources,
  /// including if they are null.
  ///
  /// This does not throw upon value parsing or validation errors,
  /// instead the caller is responsible for checking if [errors] is non-empty.
  Configuration.resolve({
    required final Iterable<O> options,
    ArgResults? argResults,
    final Iterable<String>? args,
    final Map<String, String>? env,
    final ConfigurationBroker? configBroker,
    final Map<O, Object?>? presetValues,
    final bool ignoreUnexpectedPositionalArgs = false,
  })  : _options = List<O>.from(options),
        _config = <O, OptionResolution>{},
        _errors = <String>[] {
    if (argResults == null && args != null) {
      final parser = ArgParser();
      options.prepareForParsing(parser);

      try {
        argResults = parser.parse(args);
      } on FormatException catch (e) {
        _errors.add(e.message);
        for (var o in _options) {
          _config[o] = const OptionResolution.error('Previous ArgParser error');
        }
        return;
      }
    }

    _resolveWithArgResults(
      args: argResults,
      env: env,
      configBroker: configBroker,
      presetValues: presetValues,
      ignoreUnexpectedPositionalArgs: ignoreUnexpectedPositionalArgs,
    );
  }

  /// Gets the option definitions for this configuration.
  Iterable<O> get options => _config.keys;

  /// Gets the errors that occurred during configuration resolution.
  Iterable<String> get errors => _errors;

  /// Returns the option definition for the given enum name,
  /// or any provided argument name, position,
  /// environment variable name, or configuration key.
  /// The first one that matches is returned, or null if none match.
  ///
  /// The recommended practice is to define options as enums and identify them by the enum name.
  O? findOption({
    final String? enumName,
    final String? argName,
    final int? argPos,
    final String? envName,
    final String? configKey,
  }) {
    return _options.firstWhereOrNull((final o) {
      return (enumName != null && o is Enum && (o as Enum).name == enumName) ||
          (argName != null && o.option.argName == argName) ||
          (argPos != null && o.option.argPos == argPos) ||
          (envName != null && o.option.envName == envName) ||
          (configKey != null && o.option.configKey == configKey);
    });
  }

  /// Returns the value of a configuration option
  /// identified by name, position, or key.
  ///
  /// Returns `null` if the option is not found or is not set.
  V? findValueOf<V>({
    final String? enumName,
    final String? argName,
    final int? argPos,
    final String? envName,
    final String? configKey,
  }) {
    final option = findOption(
      enumName: enumName,
      argName: argName,
      argPos: argPos,
      envName: envName,
      configKey: configKey,
    );
    if (option == null) return null;
    return optionalValue<V>(option as OptionDefinition<V>);
  }

  /// Returns the options that have a value matching
  /// the source type test.
  Iterable<O> optionsWhereSource(
    final bool Function(ValueSourceType source) test,
  ) {
    return _config.entries
        .where((final e) => test(e.value.source))
        .map((final e) => e.key);
  }

  /// Returns the value of a configuration option
  /// that is guaranteed to be non-null.
  ///
  /// Throws [UsageException] if the option is mandatory and no value is provided.
  ///
  /// If called for an option that is neither mandatory nor has defaults,
  /// [StateError] is thrown. See also [optionalValue].
  ///
  /// Throws [ArgumentError] if the option is unknown.
  V value<V>(final OptionDefinition<V> option) {
    if (!(option.option.mandatory ||
        option.option.fromDefault != null ||
        option.option.defaultsTo != null)) {
      throw StateError(
          "Can't invoke non-nullable value() for ${option.qualifiedString()} "
          'which is neither mandatory nor has a default value.');
    }
    final val = optionalValue(option);
    if (val != null) return val;

    throw InvalidParseStateError(
        'No value available for ${option.qualifiedString()} due to previous errors');
  }

  /// Returns the value of an optional configuration option.
  /// Returns `null` if the option is not set.
  ///
  /// Throws [ArgumentError] if the option is unknown.
  V? optionalValue<V>(final OptionDefinition<V> option) {
    final resolution = _getOptionResolution(option);

    return resolution.value as V?;
  }

  /// Returns the source type of the given option's value.
  ValueSourceType valueSourceType(final O option) {
    final resolution = _getOptionResolution(option);

    return resolution.source;
  }

  OptionResolution _getOptionResolution<V>(final OptionDefinition<V> option) {
    if (!_options.contains(option)) {
      throw ArgumentError(
          '${option.qualifiedString()} is not part of this configuration');
    }

    final resolution = _config[option];

    if (resolution == null) {
      throw InvalidOptionConfigurationError(option,
          'Out-of-order dependency on not-yet-resolved ${option.qualifiedString()}');
    }

    if (resolution.error != null) {
      throw InvalidParseStateError(
          'No value available for ${option.qualifiedString()} due to previous errors');
    }

    return resolution;
  }

  void _resolveWithArgResults({
    final ArgResults? args,
    final Map<String, String>? env,
    final ConfigurationBroker? configBroker,
    final Map<O, Object?>? presetValues,
    final bool ignoreUnexpectedPositionalArgs = false,
  }) {
    final posArgs = (args?.rest ?? []).iterator;
    final orderedOpts = _options.sorted((final a, final b) =>
        (a.option.argPos ?? -1).compareTo(b.option.argPos ?? -1));

    final optionGroups = <OptionGroup, Map<O, OptionResolution>>{};

    for (final opt in orderedOpts) {
      OptionResolution resolution;
      try {
        if (presetValues != null && presetValues.containsKey(opt)) {
          resolution = _resolvePresetValue(opt, presetValues[opt]);
        } else {
          resolution = opt.option.resolveValue(
            this,
            args: args,
            posArgs: posArgs,
            env: env,
            configBroker: configBroker,
          );
        }

        final group = opt.option.group;
        if (group != null) {
          optionGroups.update(
            group,
            (final value) => {...value, opt: resolution},
            ifAbsent: () => {opt: resolution},
          );
        }

        final error = resolution.error;
        if (error != null) {
          _errors.add(error);
        }
      } on InvalidParseStateError catch (e) {
        // Represents an option resolution that depends on another option
        // whose resolution failed, so this resolution fails in turn.
        // Not adding to _errors to avoid double reporting.
        resolution = OptionResolution.error(e.message);
      }

      _config[opt] = resolution;
    }

    _validateGroups(optionGroups);

    final remainingPosArgs = posArgs.restAsList();
    if (remainingPosArgs.isNotEmpty && !ignoreUnexpectedPositionalArgs) {
      _errors.add(
          "Unexpected positional argument(s): '${remainingPosArgs.join("', '")}'");
    }
  }

  OptionResolution _resolvePresetValue(
    final O option,
    final Object? value,
  ) {
    final resolution = value == null
        ? const OptionResolution.noValue()
        : OptionResolution(value: value, source: ValueSourceType.preset);

    final error = option.option.validateOptionValue(value);
    if (error != null) return resolution.copyWithError(error);
    return resolution;
  }

  void _validateGroups(
    final Map<OptionGroup, Map<O, OptionResolution>> optionGroups,
  ) {
    optionGroups.forEach((final group, final optionResolutions) {
      final error = group.validateValues(optionResolutions);
      if (error != null) {
        _errors.add(error);
      }
    });
  }
}

extension _RestAsList<T> on Iterator<T> {
  /// Returns the remaining elements of this iterator as a list.
  /// Consumes the iterator.
  List<T> restAsList() {
    final list = <T>[];
    while (moveNext()) {
      list.add(current);
    }
    return list;
  }
}

/// Specialized [StateError] that indicates that the configuration
/// has not been successfully parsed and this prevents accessing
/// some or all of the configuration values.
class InvalidParseStateError extends StateError {
  InvalidParseStateError(super.message);
}
