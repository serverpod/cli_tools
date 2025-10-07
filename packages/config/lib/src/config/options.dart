import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'configuration.dart';
import 'configuration_broker.dart';
import 'exceptions.dart';
import 'option_resolution.dart';
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
/// [name] might be used as group header in usage information
/// so it is recommended to format it appropriately, e.g. `File mode`.
///
/// An [OptionGroup] is uniquely identified by its [name].
class OptionGroup {
  final String name;

  const OptionGroup(this.name);

  /// Validates the configuration option definitions as a group.
  ///
  /// This method is called by [prepareOptionsForParsing] to validate
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
/// 4. By lookup key in configuration sources (such as files)
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
/// or a [UsageException] if the it is invalid for other reasons.
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
  final String? configKey;
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

  /// Adds this configuration option to the provided argument parser.
  void _addToArgParser(final ArgParser argParser) {
    final argName = this.argName;
    if (argName == null) {
      throw StateError("Can't add option without arg name to arg parser.");
    }
    argParser.addOption(
      argName,
      abbr: argAbbrev,
      help: helpText,
      valueHelp: valueHelpString(),
      allowed: allowedValues?.map(valueParser.format),
      allowedHelp: allowedHelp,
      defaultsTo: defaultValueString(),
      mandatory: mandatory,
      hide: hide,
      aliases: argAliases ?? const [],
    );
  }

  /// Validates the configuration option definition.
  ///
  /// This method is called by [prepareOptionsForParsing] to validate
  /// the configuration option definition.
  /// Throws an error if the definition is invalid.
  ///
  /// Subclasses may override this method to perform specific validations.
  /// If they do, they must also call the super implementation.
  @mustCallSuper
  void validateDefinition() {
    if (argName == null && argAbbrev != null) {
      throw OptionDefinitionError(this,
          "An argument option can't have an abbreviation but not a full name");
    }

    if ((fromDefault != null || defaultsTo != null) && mandatory) {
      throw OptionDefinitionError(
          this, "Mandatory options can't have default values");
    }
  }

  /// Validates the parsed value,
  /// throwing a [FormatException] if the value is invalid,
  /// or a [UsageException] if the value is invalid for other reasons.
  ///
  /// Subclasses may override this method to perform specific validations.
  /// If they do, they must also call the super implementation.
  @mustCallSuper
  void validateValue(final V value) {
    if (allowedValues?.contains(value) == false) {
      throw UsageException(
          '`$value` is not an allowed value for ${qualifiedString()}', '');
    }

    customValidator?.call(value);
  }

  /// Returns self.
  @override
  ConfigOptionBase<V> get option => this;

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
    if (configKey != null) {
      return 'configuration key `$configKey`';
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
  OptionResolution<V> resolveValue(
    final Configuration cfg, {
    final ArgResults? args,
    final Iterator<String>? posArgs,
    final Map<String, String>? env,
    final ConfigurationBroker? configBroker,
  }) {
    OptionResolution<V> res;
    try {
      res = _doResolve(
        cfg,
        args: args,
        posArgs: posArgs,
        env: env,
        configBroker: configBroker,
      );
    } on Exception catch (e) {
      return OptionResolution.error(
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

  OptionResolution<V> _doResolve(
    final Configuration cfg, {
    final ArgResults? args,
    final Iterator<String>? posArgs,
    final Map<String, String>? env,
    final ConfigurationBroker? configBroker,
  }) {
    OptionResolution<V>? result;

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

    return const OptionResolution.noValue();
  }

  OptionResolution<V>? _resolveNamedArg(final ArgResults? args) {
    final argOptName = argName;
    if (argOptName == null || args == null || !args.wasParsed(argOptName)) {
      return null;
    }
    return OptionResolution(
      stringValue: args.option(argOptName),
      source: ValueSourceType.arg,
    );
  }

  OptionResolution<V>? _resolvePosArg(final Iterator<String>? posArgs) {
    final argOptPos = argPos;
    if (argOptPos == null || posArgs == null) return null;
    if (!posArgs.moveNext()) return null;
    return OptionResolution(
      stringValue: posArgs.current,
      source: ValueSourceType.arg,
    );
  }

  OptionResolution<V>? _resolveEnvVar(final Map<String, String>? env) {
    final envVarName = envName;
    if (envVarName == null || env == null || !env.containsKey(envVarName)) {
      return null;
    }
    return OptionResolution(
      stringValue: env[envVarName],
      source: ValueSourceType.envVar,
    );
  }

  OptionResolution<V>? _resolveConfigValue(
    final Configuration cfg,
    final ConfigurationBroker? configBroker,
  ) {
    final key = configKey;
    if (configBroker == null || key == null) return null;
    final value = configBroker.valueOrNull(key, cfg);
    if (value == null) return null;
    if (value is String) {
      return OptionResolution(
        stringValue: value,
        source: ValueSourceType.config,
      );
    }
    if (value is V) {
      return OptionResolution(
        value: value as V,
        source: ValueSourceType.config,
      );
    }
    return OptionResolution.error(
      '${option.qualifiedString()} value $value '
      'is of type ${value.runtimeType}, not $V.',
    );
  }

  OptionResolution<V>? _resolveCustomValue(final Configuration cfg) {
    final value = fromCustom?.call(cfg);
    if (value == null) return null;
    return OptionResolution(
      value: value,
      source: ValueSourceType.custom,
    );
  }

  OptionResolution<V>? _resolveDefaultValue() {
    final value = fromDefault?.call() ?? defaultsTo;
    if (value == null) return null;
    return OptionResolution(
      value: value,
      source: ValueSourceType.defaultValue,
    );
  }

  /// Returns an error message if the value is invalid, or null if valid.
  ///
  /// This method is intended for internal use.
  String? validateOptionValue(final V? value) {
    if (value == null && mandatory) {
      return '${qualifiedString()} is mandatory';
    }

    if (value != null) {
      try {
        validateValue(value);
      } on FormatException catch (e) {
        return _makeFormatErrorMessage(e);
      } on UsageException catch (e) {
        return _makeErrorMessage(e.message);
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
  void _addToArgParser(final ArgParser argParser) {
    final argName = this.argName;
    if (argName == null) {
      throw StateError("Can't add flag without arg name to arg parser.");
    }
    argParser.addFlag(
      argName,
      abbr: argAbbrev,
      help: helpText,
      defaultsTo: defaultValue(),
      negatable: negatable,
      hideNegatedUsage: hideNegatedUsage,
      hide: hide,
      aliases: argAliases ?? const [],
    );
  }

  @override
  OptionResolution<bool>? _resolveNamedArg(final ArgResults? args) {
    final argOptName = argName;
    if (argOptName == null || args == null || !args.wasParsed(argOptName)) {
      return null;
    }
    return OptionResolution(
      value: args.flag(argOptName),
      source: ValueSourceType.arg,
    );
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
  })  : allowedElementValues = allowedValues,
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
  void _addToArgParser(final ArgParser argParser) {
    final argName = this.argName;
    if (argName == null) {
      throw StateError("Can't add option without arg name to arg parser.");
    }

    argParser.addMultiOption(
      argName,
      abbr: argAbbrev,
      help: helpText,
      valueHelp: valueHelpString(),
      allowed: allowedElementValues?.map(multiParser.elementParser.format),
      allowedHelp: allowedHelp,
      defaultsTo: defaultValue()?.map(multiParser.elementParser.format),
      hide: hide,
      splitCommas: multiParser.separator == ',',
      aliases: argAliases ?? const [],
    );
  }

  @override
  OptionResolution<List<T>>? _resolveNamedArg(final ArgResults? args) {
    final argOptName = argName;
    if (argOptName == null || args == null || !args.wasParsed(argOptName)) {
      return null;
    }
    final multiParser = valueParser as MultiParser<T>;
    return OptionResolution(
      value: args
          .multiOption(argOptName)
          .map(multiParser.elementParser.parse)
          .toList(),
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
          throw UsageException(
              '`$v` is not an allowed value for ${qualifiedString()}', '');
        }
      }
    }
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

/// Validates and prepares a set of options for the provided argument parser.
void prepareOptionsForParsing(
  final Iterable<OptionDefinition> options,
  final ArgParser argParser,
) {
  final argNameOpts = validateOptions(options);
  addOptionsToParser(argNameOpts, argParser);
}

Iterable<OptionDefinition> validateOptions(
  final Iterable<OptionDefinition> options,
) {
  final argNameOpts = <String, OptionDefinition>{};
  final argPosOpts = <int, OptionDefinition>{};
  final envNameOpts = <String, OptionDefinition>{};

  final optionGroups = <OptionGroup, List<OptionDefinition>>{};

  for (final opt in options) {
    opt.option.validateDefinition();

    final argName = opt.option.argName;
    if (argName != null) {
      if (argNameOpts.containsKey(opt.option.argName)) {
        throw OptionDefinitionError(
            opt, 'Duplicate argument name: ${opt.option.argName} for $opt');
      }
      argNameOpts[argName] = opt;
    }

    final argPos = opt.option.argPos;
    if (argPos != null) {
      if (argPosOpts.containsKey(opt.option.argPos)) {
        throw OptionDefinitionError(
            opt, 'Duplicate argument position: ${opt.option.argPos} for $opt');
      }
      argPosOpts[argPos] = opt;
    }

    final envName = opt.option.envName;
    if (envName != null) {
      if (envNameOpts.containsKey(opt.option.envName)) {
        throw OptionDefinitionError(opt,
            'Duplicate environment variable name: ${opt.option.envName} for $opt');
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
        (final a, final b) => a.option.argPos!.compareTo(b.option.argPos!));

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

  return argNameOpts.values;
}

void addOptionsToParser(
  final Iterable<OptionDefinition> argNameOpts,
  final ArgParser argParser,
) {
  // Gather all necessary Option Group information
  final optionGroups = <OptionGroup, List<OptionDefinition>>{}; // ordered map
  final grouplessOptions = <OptionDefinition>[]; // ordered list
  for (final opt in argNameOpts) {
    final group = opt.option.group;
    if (group != null) {
      optionGroups.update(
        group,
        (final options) => options..add(opt),
        ifAbsent: () => [opt],
      );
    } else {
      grouplessOptions.add(opt);
    }
  }
  final nOptionGroups = optionGroups.keys.length;

  // Helpers for consistent processing and validation
  const defaultFallbackGroupName = 'Option Group';
  void addOne(final OptionDefinition x) => x.option._addToArgParser(argParser);
  void addAll(final List<OptionDefinition> options) => options.forEach(addOne);
  bool isNotBlank(final String name) => name.trim().isNotEmpty;
  String buildFallbackGroupName(final int groupCounter) =>
      '$defaultFallbackGroupName${nOptionGroups > 1 ? " $groupCounter" : ""}';

  // Add all Groupless Options first (in order)
  addAll(grouplessOptions);

  // Add all Groups (in order) and their Options (in order)
  var groupCounter = 0;
  optionGroups.forEach((final group, final options) {
    ++groupCounter;
    var givenGroupName = group.name;
    var fallbackGroupName = buildFallbackGroupName(groupCounter);

    // IMPORTANT NOTE for this If-Block:
    // - resolves some bug which fails newline padding in this particular case
    // - the bug was probably bubbled down from the external Args Package
    // - this code MUST BE REMOVED WHEN THIS BUG IS RESOLVED
    // - when this block is removed, both the Group Names can be `final`.
    //
    // Unit Tests for Group Usage Text covers this case, so
    // it shall serve as a reminder by failing when this bug gets patched.
    if (groupCounter == 1 && grouplessOptions.isEmpty) {
      givenGroupName = '$givenGroupName\n';
      fallbackGroupName = '$fallbackGroupName\n';
    }

    // Add the Group Name after handling potential Blank Names
    argParser.addSeparator(
      isNotBlank(givenGroupName) ? givenGroupName : fallbackGroupName,
    );

    // Add all the Grouped Options (in order)
    addAll(options);
  });
}

extension PrepareOptions on Iterable<OptionDefinition> {
  /// Validates and prepares these options for the provided argument parser.
  void prepareForParsing(final ArgParser argParser) =>
      prepareOptionsForParsing(this, argParser);

  /// Returns the usage help text for these options.
  String get usage {
    final parser = ArgParser();
    prepareForParsing(parser);
    return parser.usage;
  }
}
