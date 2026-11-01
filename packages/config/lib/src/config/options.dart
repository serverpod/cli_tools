import 'dart:async' show FutureOr;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'arg_parser_bridge.dart';
import 'arg_parser_facade.dart';
import 'completion.dart';
import 'configuration.dart' show Configuration;
import 'configuration_broker.dart';
import 'exceptions.dart';
import 'option_resolution.dart';
import 'option_resolution_impl.dart';
import 'source_type.dart';

/// Common interface to enable same treatment for [ConfigOptionBase]
/// and option enums.
///
/// [V] is the type of the value this option provides.
///
/// ## Example
///
/// The typical usage pattern is to use an enum with the options
/// and implement this interface like so:
/// ```dart
/// enum MyAppOption<V> implements OptionDefinition<V> {
///   username(StringOption(
///     argName: 'username',
///     envName: 'USERNAME',
///   ));
///
///   const MyAppOption(this.option);
///
///   @override
///   final ConfigOptionBase<V> option;
/// }
/// ```
///
/// See [ConfigOptionBase] for more information on options,
/// and [Configuration] on how to initialize the configuration.
abstract interface class OptionDefinition<V> {
  ConfigOptionBase<V> get option;
}

/// An option group allows grouping options together under a common name,
/// and optionally provide option value validation on the group as a whole.
///
/// [name] shall be used as group header in usage information
/// so it is recommended to format it appropriately, e.g. `File mode`.
///
/// An [OptionGroup] is uniquely identified by its [name].
class OptionGroup {
  final String name;

  const OptionGroup(this.name);

  /// Validates the configuration option definitions as a group.
  ///
  /// This method is called by [validateOptions] to validate
  /// the configuration option definitions as a group.
  /// Throws an error if any definition is invalid as part of this group.
  ///
  /// Subclasses may override this method to perform specific validations.
  void validateDefinitions(final List<OptionDefinition> options) {}

  /// Validates the values of the options in this group,
  /// returning a descriptive error message if the values are invalid.
  ///
  /// Subclasses may override this method to perform specific validations.
  String? validateValues(
    final Map<OptionDefinition, OptionResolution> optionResolutions,
  ) {
    return null;
  }

  @override
  bool operator ==(final Object other) {
    if (identical(this, other)) return true;
    return other is OptionGroup && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;
}

/// A [ValueParser] converts a source string value to the specific option
/// value type.
///
/// {@template value_parser}
/// Must throw a [FormatException] with an appropriate message
/// if the value cannot be parsed.
/// {@endtemplate}
abstract class ValueParser<V> {
  const ValueParser();

  /// Converts a source string value to the specific option value type.
  /// {@macro value_parser}
  V parse(final String value);

  /// Returns a usage documentation friendly string representation of the value.
  /// The default implementation simply invokes [toString].
  String format(final V value) {
    return value.toString();
  }
}

/// Defines a configuration option that can be set from configuration sources.
///
/// When an option can be set in multiple ways, the precedence is as follows:
///
/// 1. Named command line argument
/// 2. Positional command line argument
/// 3. Environment variable
/// 4. By lookup key in configuration sources (such as files).
///    If multiple keys are specified, they are tried in order.
/// 5. A custom callback function
/// 6. Default value
///
/// ### Typed values, parsing, and validation
///
/// [V] is the type of the value this option provides.
/// Option values are parsed to this type using the [ValueParser].
/// Subclasses of [ConfigOptionBase] may also override [validateValue]
/// to perform additional validation such as range checking.
///
/// The subclasses implement specific option value types,
/// e.g. [StringOption], [FlagOption] (boolean), [IntOption], etc.
///
/// A [customValidator] may be provided for an individual option.
/// If a value was provided the customValidator is invoked,
/// and shall throw a [FormatException] if its format is invalid,
/// or a [InvalidValueException] if the it is invalid for other reasons.
///
/// ### Positional arguments
///
/// If multiple positional arguments are defined,
/// follow these restrictions to prevent ambiguity:
///  - all but the last one must be mandatory
///  - all but the last one must have no non-argument configuration sources
///
/// If an argument is defined as both named and positional,
/// and the named argument is provided, the positional index
/// is still consumed so that subsequent positional arguments
/// will get the correct value.
///
/// Note that this prevents an option from being provided both
/// named and positional on the same command line.
///
/// ### Mandatory and Default
///
/// If [mandatory] is true, the option must be provided in the
/// configuration sources, i.e. be explicitly set.
/// This cannot be used together with [defaultsTo] or [fromDefault].
///
/// If no value is provided from the configuration sources,
/// the [fromDefault] callback is used if available,
/// otherwise the [defaultsTo] value is used.
/// [fromDefault] must return the same value if called multiple times.
///
/// If an option is either mandatory or has a default value,
/// it is guaranteed to have a value and can be retrieved using
/// the non-nullable [value] method.
/// Otherwise it may be retrieved using the nullable [valueOrNull] method.
///
/// ## Example
///
/// The typical usage pattern is to use an enum with the options
/// and instantiate subclasses of [ConfigOptionBase] like so:
/// ```dart
/// enum MyAppOption<V> implements OptionDefinition<V> {
///   username(StringOption(
///     argName: 'username',
///     envName: 'USERNAME',
///   ));
///
///   const MyAppOption(this.option);
///
///   @override
///   final ConfigOptionBase<V> option;
/// }
/// ```
///
/// See [Configuration] on how to initialize the configuration.
abstract class ConfigOptionBase<V> implements OptionDefinition<V> {
  final ValueParser<V> valueParser;

  final String? argName;
  final List<String>? argAliases;
  final String? argAbbrev;
  final int? argPos;
  final String? envName;

  /// A single configuration source lookup key.
  ///
  /// For multiple sources, use [configKeys] instead, or specify both:
  /// [configKey] is tried first, then each key in [configKeys].
  final String? configKey;

  /// Configuration source lookup keys, in order of precedence.
  ///
  /// Keys are tried in order until a value is found.
  /// If [configKey] is also set, it is tried first.
  final List<String>? configKeys;

  final V? Function(Configuration cfg)? fromCustom;
  final V Function()? fromDefault;
  final V? defaultsTo;

  final String? helpText;
  final String? valueHelp;
  final Map<String, String>? allowedHelp;
  final OptionGroup? group;

  final List<V>? allowedValues;
  final void Function(V value)? customValidator;
  final bool mandatory;
  final bool hide;

  const ConfigOptionBase({
    required this.valueParser,
    this.argName,
    this.argAliases,
    this.argAbbrev,
    this.argPos,
    this.envName,
    this.configKey,
    this.configKeys,
    this.fromCustom,
    this.fromDefault,
    this.defaultsTo,
    this.helpText,
    this.valueHelp,
    this.allowedHelp,
    this.group,
    this.allowedValues,
    this.customValidator,
    this.mandatory = false,
    this.hide = false,
  });

  /// Configuration lookup keys in order of precedence.
  ///
  /// Includes [configKey] if set, followed by [configKeys] if set.
  List<String> get allConfigKeys {
    final key = configKey;
    final keys = configKeys;
    return [?key, ...?keys];
  }

  V? defaultValue() {
    final df = fromDefault;
    return (df != null ? df() : defaultsTo);
  }

  String? defaultValueString() {
    final defValue = defaultValue();
    if (defValue == null) return null;
    return valueParser.format(defValue);
  }

  String? valueHelpString() {
    return valueHelp;
  }

  /// Validates the configuration option definition.
  ///
  /// This method is called by [validateOptions] to validate
  /// the configuration option definition.
  /// Throws an error if the definition is invalid.
  ///
  /// Subclasses may override this method to perform specific validations.
  /// If they do, they must also call the super implementation.
  @mustCallSuper
  void validateDefinition() {
    final fullName = argName;
    if (fullName == null) {
      if (argAbbrev != null) {
        throw OptionDefinitionError(
          this,
          "An argument option can't have an abbreviation but not a full name",
        );
      }
      if (argAliases?.isNotEmpty == true) {
        throw OptionDefinitionError(
          this,
          "An argument option can't have aliases but not a full name",
        );
      }
    } else {
      if (fullName.contains('=') == true || argAbbrev?.contains('=') == true) {
        throw OptionDefinitionError(
          this,
          "An argument option name / abbreviation can't contain '='",
        );
      }
      if (fullName.startsWith('-') == true ||
          argAbbrev?.startsWith('-') == true) {
        throw OptionDefinitionError(
          this,
          "An argument option name / abbreviation can't start with '-'",
        );
      }
    }
    if (argAliases?.any((final alias) => alias.contains('=')) == true) {
      throw OptionDefinitionError(
        this,
        "An argument option alias can't contain '='",
      );
    }
    if (argAliases?.any((final alias) => alias.startsWith('-')) == true) {
      throw OptionDefinitionError(
        this,
        "An argument option alias can't start with '-'",
      );
    }

    if ((fromDefault != null || defaultsTo != null) && mandatory) {
      throw OptionDefinitionError(
        this,
        "Mandatory options can't have default values",
      );
    }
  }

  /// Validates the parsed value,
  /// throwing a [FormatException] if the value is invalid,
  /// or a [InvalidValueException] if the value is invalid for other reasons.
  ///
  /// Subclasses may override this method to perform specific validations.
  /// If they do, they must also call the super implementation.
  @mustCallSuper
  void validateValue(final V value) {
    if (allowedValues?.contains(value) == false) {
      throw InvalidValueException(
        '`$value` is not an allowed value for ${qualifiedString()}',
      );
    }

    customValidator?.call(value);
  }

  /// Returns self.
  @override
  ConfigOptionBase<V> get option => this;

  /////////////////////
  // Command line completion

  /// Returns the command line completion alternatives for a value of this
  /// option.
  ///
  /// Invoked by the command runner when the shell requests completion of a
  /// value for this option. [context] describes the command line typed so far,
  /// including the partial [CompletionContext.wordToComplete].
  ///
  /// The default implementation offers [allowedValues] when set, with
  /// descriptions from [allowedHelp]; otherwise the keys of [allowedHelp]
  /// when set; otherwise it requests native file completion from the shell.
  ///
  /// Subclasses override this for type-specific behavior, for example
  /// [EnumOption] offers the enum names and [DirOption] offers directories.
  /// A custom option type can override this to offer any alternatives,
  /// for example names fetched from a server. The implementation may be
  /// asynchronous, but must be fast and should not throw. If it throws,
  /// nothing is offered.
  ///
  /// The candidates need not be filtered by [CompletionContext.wordToComplete]
  /// since the shells do that; filtering is still recommended for large sets.
  FutureOr<CompletionResult> complete(final CompletionContext context) {
    final candidates = allowedValueCandidates();
    if (candidates != null) return CompletionResult.values(candidates);
    return const CompletionResult.files();
  }

  /// Returns completion candidates for [allowedValues] with descriptions
  /// from [allowedHelp], or for the keys of [allowedHelp] alone,
  /// or null if neither is set.
  @protected
  List<CompletionCandidate>? allowedValueCandidates() {
    final allowed = allowedValues;
    if (allowed != null) return candidatesForValues(allowed);

    final help = allowedHelp;
    if (help != null) {
      return [
        for (final entry in help.entries)
          CompletionCandidate(entry.key, description: entry.value),
      ];
    }
    return null;
  }

  /// Returns completion candidates for [values], formatted with
  /// [valueParser] and described by [allowedHelp] when available.
  @protected
  List<CompletionCandidate> candidatesForValues(final Iterable<V> values) {
    final help = allowedHelp;
    return [
      for (final value in values)
        if (valueParser.format(value) case final formatted)
          CompletionCandidate(formatted, description: help?[formatted]),
    ];
  }

  // TODO: Present arg options including the '--' prefix,
  //       and {position 0} for positional arguments without a name.
  @override
  String toString() => argName ?? envName ?? '<unnamed option>';

  String qualifiedString() {
    if (argName != null) {
      return V is bool ? 'flag `$argName`' : 'option `$argName`';
    }
    if (envName != null) {
      return 'environment variable `$envName`';
    }
    if (argPos != null) {
      return 'positional argument $argPos';
    }
    final keys = allConfigKeys;
    if (keys.isNotEmpty) {
      if (keys.length == 1) {
        return 'configuration key `${keys.single}`';
      }
      return 'configuration keys ${keys.map((final k) => '`$k`').join(', ')}';
    }
    return _unnamedOptionString;
  }

  static const _unnamedOptionString = '<unnamed option>';

  /////////////////////
  // Value resolution

  /// Returns the resolved value of this configuration option from the provided context.
  /// For options with positional arguments this must be invoked in ascending position order.
  /// Returns the result with the resolved value or error.
  ///
  /// This method is intended for internal use.
  @internal
  OptionResolutionImpl<V> resolveValue(
    final Configuration cfg, {
    final ParsedArgs? args,
    final Iterator<String>? posArgs,
    final Map<String, String>? env,
    final ConfigurationBroker? configBroker,
  }) {
    OptionResolutionImpl<V> res;
    try {
      res = _doResolve(
        cfg,
        args: args,
        posArgs: posArgs,
        env: env,
        configBroker: configBroker,
      );
    } on Exception catch (e) {
      return OptionResolutionImpl.error(
        'Failed to resolve ${option.qualifiedString()}: $e',
      );
    }

    if (res.error != null) {
      return res;
    }

    final stringValue = res.stringValue;
    if (stringValue != null) {
      // value provided by string-based config source, parse to the designated type
      try {
        res = res.copyWithValue(
          option.option.valueParser.parse(stringValue),
        );
      } on FormatException catch (e) {
        return res.copyWithError(
          _makeFormatErrorMessage(e),
        );
      }
    }

    final error = validateOptionValue(res.value);
    if (error != null) return res.copyWithError(error);

    return res;
  }

  OptionResolutionImpl<V> _doResolve(
    final Configuration cfg, {
    final ParsedArgs? args,
    final Iterator<String>? posArgs,
    final Map<String, String>? env,
    final ConfigurationBroker? configBroker,
  }) {
    OptionResolutionImpl<V>? result;

    result = _resolveNamedArg(args);
    if (result != null) return result;

    result = _resolvePosArg(posArgs);
    if (result != null) return result;

    result = _resolveEnvVar(env);
    if (result != null) return result;

    result = _resolveConfigValue(cfg, configBroker);
    if (result != null) return result;

    result = _resolveCustomValue(cfg);
    if (result != null) return result;

    result = _resolveDefaultValue();
    if (result != null) return result;

    return const OptionResolutionImpl.noValue();
  }

  OptionResolutionImpl<V>? _resolveNamedArg(final ParsedArgs? args) {
    if (argName == null || args == null || !args.wasParsed(this)) {
      return null;
    }
    return OptionResolutionImpl(
      stringValue: args.option(this),
      source: ValueSourceType.arg,
    );
  }

  OptionResolutionImpl<V>? _resolvePosArg(final Iterator<String>? posArgs) {
    final argOptPos = argPos;
    if (argOptPos == null || posArgs == null) return null;
    if (!posArgs.moveNext()) return null;
    return OptionResolutionImpl(
      stringValue: posArgs.current,
      source: ValueSourceType.arg,
    );
  }

  OptionResolutionImpl<V>? _resolveEnvVar(final Map<String, String>? env) {
    final envVarName = envName;
    if (envVarName == null || env == null || !env.containsKey(envVarName)) {
      return null;
    }
    return OptionResolutionImpl(
      stringValue: env[envVarName],
      source: ValueSourceType.envVar,
    );
  }

  OptionResolutionImpl<V>? _resolveConfigValue(
    final Configuration cfg,
    final ConfigurationBroker? configBroker,
  ) {
    if (configBroker == null) return null;
    final keys = allConfigKeys;
    if (keys.isEmpty) return null;

    Object? value;
    for (final key in keys) {
      value = configBroker.valueOrNull(key, cfg);
      if (value != null) break;
    }
    if (value == null) return null;
    if (value is String) {
      return OptionResolutionImpl(
        stringValue: value,
        source: ValueSourceType.config,
      );
    }
    if (value is V) {
      return OptionResolutionImpl(
        value: value as V,
        source: ValueSourceType.config,
      );
    }
    return OptionResolutionImpl.error(
      '${option.qualifiedString()} value $value '
      'is of type ${value.runtimeType}, not $V.',
    );
  }

  OptionResolutionImpl<V>? _resolveCustomValue(final Configuration cfg) {
    final value = fromCustom?.call(cfg);
    if (value == null) return null;
    return OptionResolutionImpl(
      value: value,
      source: ValueSourceType.custom,
    );
  }

  OptionResolutionImpl<V>? _resolveDefaultValue() {
    final value = fromDefault?.call() ?? defaultsTo;
    if (value == null) return null;
    return OptionResolutionImpl(
      value: value,
      source: ValueSourceType.defaultValue,
    );
  }

  /// Returns an error message if the value is invalid, or null if valid.
  ///
  /// This method is intended for internal use.
  @internal
  String? validateOptionValue(final V? value) {
    if (value == null && mandatory) {
      return '${qualifiedString()} is mandatory';
    }

    if (value != null) {
      try {
        validateValue(value);
      } on FormatException catch (e) {
        return _makeFormatErrorMessage(e);
      } on InvalidValueException catch (e) {
        return _makeErrorMessage(e.message);
      } on UsageException catch (e) {
        // Retained for backwards compatibility for users who may have custom
        // option implementations that throw UsageException.
        // TODO: Remove in a future version.
        return _makeErrorMessage(e.toString());
      }
    }
    return null;
  }

  String _makeFormatErrorMessage(final FormatException e) {
    const prefix = 'FormatException: ';
    var message = e.toString();
    if (message.startsWith(prefix)) {
      message = message.substring(prefix.length);
    }
    return _makeErrorMessage(message);
  }

  String _makeErrorMessage(final String message) {
    final help = valueHelp != null ? ' <$valueHelp>' : '';
    return 'Invalid value for ${qualifiedString()}$help: $message';
  }
}

/// Parses a boolean value from a string.
class BoolParser extends ValueParser<bool> {
  const BoolParser();

  @override
  bool parse(final String value) {
    return bool.parse(value, caseSensitive: false);
  }
}

/// Boolean value configuration option.
class FlagOption extends ConfigOptionBase<bool> {
  final bool negatable;
  final bool hideNegatedUsage;

  const FlagOption({
    super.argName,
    super.argAliases,
    super.argAbbrev,
    super.envName,
    super.configKey,
    super.configKeys,
    super.fromCustom,
    super.fromDefault,
    super.defaultsTo,
    super.helpText,
    super.valueHelp,
    super.group,
    super.customValidator,
    super.mandatory,
    super.hide,
    this.negatable = true,
    this.hideNegatedUsage = false,
  }) : super(
         valueParser: const BoolParser(),
       );

  @override
  void validateDefinition() {
    super.validateDefinition();
    if (argName?.startsWith('no-') == true) {
      throw OptionDefinitionError(
        this,
        "A flag name can't start with 'no-'",
      );
    }
  }

  @override
  OptionResolutionImpl<bool>? _resolveNamedArg(final ParsedArgs? args) {
    if (argName == null || args == null || !args.wasParsed(this)) {
      return null;
    }
    return OptionResolutionImpl(
      value: args.flag(this),
      source: ValueSourceType.arg,
    );
  }

  /// A flag takes no value on the command line, so there is nothing to offer.
  @override
  FutureOr<CompletionResult> complete(final CompletionContext context) {
    return const CompletionResult.none();
  }
}

/// Parses a list of values from a comma-separated string.
///
/// The [elementParser] is used to parse the individual elements.
///
/// The [separator] is the pattern that separates the elements,
/// if the input is a single string. It is comma by default.
/// If it is null, the input is treated as a single element.
///
/// The [joiner] is the string that joins the elements in the
/// formatted display string, also comma by default.
class MultiParser<T> extends ValueParser<List<T>> {
  final ValueParser<T> elementParser;
  final Pattern? separator;
  final String joiner;

  const MultiParser(
    this.elementParser, {
    this.separator = ',',
    this.joiner = ',',
  });

  @override
  List<T> parse(final String value) {
    final sep = separator;
    if (sep == null) return [elementParser.parse(value)];
    return value.split(sep).map(elementParser.parse).toList();
  }

  @override
  String format(final List<T> value) {
    return value.map(elementParser.format).join(joiner);
  }
}

/// Multi-value configuration option.
class MultiOption<T> extends ConfigOptionBase<List<T>> {
  final MultiParser<T> multiParser;
  final List<T>? allowedElementValues;

  const MultiOption({
    required this.multiParser,
    super.argName,
    super.argAliases,
    super.argAbbrev,
    super.envName,
    super.configKey,
    super.configKeys,
    super.fromCustom,
    super.fromDefault,
    super.defaultsTo,
    super.helpText,
    super.valueHelp,
    super.allowedHelp,
    super.group,
    final List<T>? allowedValues,
    super.customValidator,
    super.mandatory,
    super.hide,
  }) : allowedElementValues = allowedValues,
       super(
         valueParser: multiParser,
       );

  /// [MultiOption] does not properly support [allowedValues],
  /// use [allowedElementValues] instead.
  @override
  List<List<T>>? get allowedValues {
    return super.allowedValues;
  }

  @override
  OptionResolutionImpl<List<T>>? _resolveNamedArg(final ParsedArgs? args) {
    if (argName == null || args == null || !args.wasParsed(this)) {
      return null;
    }
    final multiParser = valueParser as MultiParser<T>;
    return OptionResolutionImpl(
      value: args.multiOption(this).expand(multiParser.parse).toList(),
      source: ValueSourceType.arg,
    );
  }

  @override
  @mustCallSuper
  void validateValue(final List<T> value) {
    super.validateValue(value);

    final allowed = allowedElementValues;
    if (allowed != null) {
      for (final v in value) {
        if (allowed.contains(v) == false) {
          throw InvalidValueException(
            '`$v` is not an allowed value for ${qualifiedString()}',
          );
        }
      }
    }
  }

  /// Offers the [allowedElementValues] when set, with descriptions from
  /// [allowedHelp]; otherwise the keys of [allowedHelp] when set;
  /// otherwise native file completion.
  ///
  /// The command runner completes the element after the last separator,
  /// when the [MultiParser.separator] is a string.
  @override
  FutureOr<CompletionResult> complete(final CompletionContext context) {
    final allowed = allowedElementValues;
    if (allowed != null) {
      final help = allowedHelp;
      return CompletionResult.values([
        for (final value in allowed)
          if (multiParser.elementParser.format(value) case final formatted)
            CompletionCandidate(formatted, description: help?[formatted]),
      ]);
    }
    return super.complete(context);
  }
}

/// Extension to add a [qualifiedString] shorthand method to [OptionDefinition].
/// Since enum classes that implement [OptionDefinition] don't inherit
/// its method implementations, this extension provides this method
/// implementation instead.
extension QualifiedString on OptionDefinition {
  String qualifiedString() {
    final str = option.qualifiedString();
    if (str == ConfigOptionBase._unnamedOptionString && this is Enum) {
      return (this as Enum).name;
    }
    return str;
  }
}

/// Validates a set of options.
///
/// Throws an [OptionDefinitionError] if the options are invalid.
///
/// Returns an iterable of the options that are specifyable with an argument
/// name on the command line.
List<OptionDefinition> validateOptions(
  final Iterable<OptionDefinition> options,
) {
  final argNameOpts = <String, OptionDefinition>{};
  final argPosOpts = <int, OptionDefinition>{};
  final envNameOpts = <String, OptionDefinition>{};
  final claimedNames = <String, OptionDefinition>{};
  final claimedAbbrevs = <String, OptionDefinition>{};

  final optionGroups = <OptionGroup, List<OptionDefinition>>{};

  for (final opt in options) {
    opt.option.validateDefinition();

    final argName = opt.option.argName;
    if (argName != null) {
      _claimOptionArgs(opt, claimedNames, claimedAbbrevs);
      argNameOpts[argName] = opt;
    }

    final argPos = opt.option.argPos;
    if (argPos != null) {
      if (argPosOpts.containsKey(opt.option.argPos)) {
        throw OptionDefinitionError(
          opt,
          'Duplicate argument position: ${opt.option.argPos} for $opt',
        );
      }
      argPosOpts[argPos] = opt;
    }

    final envName = opt.option.envName;
    if (envName != null) {
      if (envNameOpts.containsKey(opt.option.envName)) {
        throw OptionDefinitionError(
          opt,
          'Duplicate environment variable name: ${opt.option.envName} for $opt',
        );
      }
      envNameOpts[envName] = opt;
    }

    final group = opt.option.group;
    if (group != null) {
      optionGroups.update(
        group,
        (final value) => [...value, opt],
        ifAbsent: () => [opt],
      );
    }
  }

  optionGroups.forEach((final group, final options) {
    group.validateDefinitions(options);
  });

  if (argPosOpts.isNotEmpty) {
    final orderedPosOpts = argPosOpts.values.sorted(
      (final a, final b) => a.option.argPos!.compareTo(b.option.argPos!),
    );

    if (orderedPosOpts.first.option.argPos != 0) {
      throw OptionDefinitionError(
        orderedPosOpts.first,
        'First positional argument must have index 0.',
      );
    }

    if (orderedPosOpts.last.option.argPos != orderedPosOpts.length - 1) {
      throw OptionDefinitionError(
        orderedPosOpts.last,
        'The positional arguments must have consecutive indices without gaps.',
      );
    }
  }

  return argNameOpts.values.toList();
}

void _claimOptionArgs(
  final OptionDefinition opt,
  final Map<String, OptionDefinition> names,
  final Map<String, OptionDefinition> abbrevs,
) {
  final argName = opt.option.argName;
  if (argName == null) return;

  _claimArg(
    names,
    argName,
    opt,
    'Duplicate argument name: $argName for $opt',
  );
  if (opt.option case final FlagOption flag when flag.negatable) {
    final negation = 'no-$argName';
    _claimArg(
      names,
      negation,
      opt,
      'Duplicate argument name: $negation for $opt',
    );
  }

  if (opt.option.argAliases case final List<String> aliases) {
    for (final alias in aliases) {
      _claimArg(
        names,
        alias,
        opt,
        'Duplicate argument name: $alias for $opt',
      );
    }
  }

  if (opt.option.argAbbrev case final String abbrev) {
    _claimArg(
      abbrevs,
      abbrev,
      opt,
      'Duplicate argument abbreviation: $abbrev for $opt',
    );
  }
}

void _claimArg(
  final Map<String, OptionDefinition> claimed,
  final String key,
  final OptionDefinition opt,
  final String message,
) {
  if (claimed.containsKey(key)) {
    throw OptionDefinitionError(opt, message);
  }
  claimed[key] = opt;
}

extension PrepareOptions on Iterable<OptionDefinition> {
  /// Returns the usage help text for these options.
  String get usage {
    return oldUsage(this);
  }

  /// Returns the option definition for the given enum name,
  /// or any provided argument name, position,
  /// environment variable name, or configuration key.
  /// The first one that matches is returned, or null if none match.
  ///
  /// The recommended practice is to define options as enums and identify them by the enum name.
  OptionDefinition? findOption({
    final String? enumName,
    final String? argName,
    final int? argPos,
    final String? envName,
    final String? configKey,
  }) {
    return firstWhereOrNull((final o) {
      return (enumName != null && o is Enum && (o as Enum).name == enumName) ||
          (argName != null && o.option.argName == argName) ||
          (argPos != null && o.option.argPos == argPos) ||
          (envName != null && o.option.envName == envName) ||
          (configKey != null && o.option.allConfigKeys.contains(configKey));
    });
  }
}
