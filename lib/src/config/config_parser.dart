import 'package:args/args.dart';
import 'package:args/command_runner.dart' show UsageException;

import 'configuration.dart';
import 'options.dart';
import 'source_type.dart';

/// A backwards compatible parser for command args and configuration sources.
///
/// This class is designed as a drop-in replacement for [ArgParser]
/// of the `args` package. It is almost entirely compatible except for:
/// - addCommand() is not supported
///
/// The [parse] method returns a [ConfigResults] object which is a backwards
/// compatible with [ArgResults] of the args package.
///
/// The purpose of this class is to enable an easy transition to the
/// configuration package. This can be dropped in place of existing `args`
/// code and gradually extended to use multiple configuration sources
/// such as environment variables and configuration files.
///
/// It is recommended to migrate to the [Configuration] class to enable the
/// full range of typed configuration values.
class ConfigParser implements ArgParser {
  final ArgParser _parser;
  final List<OptionDefinition> _optionDefinitions = [];
  final Map<String, void Function(bool)> _flagCallbacks = {};
  final Map<String, void Function(String?)> _optionCallbacks = {};
  final Map<String, void Function(List<String>)> _multiOptionCallbacks = {};

  ConfigParser({
    final bool allowTrailingOptions = true,
    final int? usageLineLength,
  }) : _parser = ArgParser(
          allowTrailingOptions: allowTrailingOptions,
          usageLineLength: usageLineLength,
        );

  ArgParser get parser => _parser;

  List<OptionDefinition> get optionDefinitions => _optionDefinitions;

  @override
  void addFlag(
    final String name, {
    final String? abbr,
    final String? help,
    final bool? defaultsTo = false,
    final bool negatable = true,
    @Deprecated('Use parse results instead')
    final void Function(bool)? callback,
    final bool hide = false,
    final bool hideNegatedUsage = false,
    final List<String> aliases = const [],
    final String? envName,
    final String? configKey,
    final bool? Function(Configuration cfg)? fromCustom,
    final bool Function()? fromDefault,
    final String? valueHelp,
    final bool mandatory = false,
    final OptionGroup? group,
    final void Function(bool value)? customValidator,
  }) {
    _addOption(
      FlagOption(
        argName: name,
        argAliases: aliases,
        argAbbrev: abbr,
        envName: envName,
        configKey: configKey,
        fromCustom: fromCustom,
        fromDefault: fromDefault,
        defaultsTo: defaultsTo,
        helpText: help,
        valueHelp: valueHelp,
        group: group,
        customValidator: customValidator,
        mandatory: mandatory,
        hide: hide,
        negatable: negatable,
        hideNegatedUsage: hideNegatedUsage,
      ),
    );
    if (callback != null) {
      _flagCallbacks[name] = callback;
    }
  }

  @override
  void addOption(
    final String name, {
    final String? abbr,
    final String? help,
    final String? valueHelp,
    final Iterable<String>? allowed,
    final Map<String, String>? allowedHelp,
    final String? defaultsTo,
    @Deprecated('Use parse results instead')
    final void Function(String?)? callback,
    final bool mandatory = false,
    final bool hide = false,
    final List<String> aliases = const [],
    final int? argPos,
    final String? envName,
    final String? configKey,
    final String? Function(Configuration cfg)? fromCustom,
    final String Function()? fromDefault,
    final OptionGroup? group,
    final void Function(String value)? customValidator,
  }) {
    _addOption(
      StringOption(
        argName: name,
        argAliases: aliases,
        argAbbrev: abbr,
        argPos: argPos,
        envName: envName,
        configKey: configKey,
        fromCustom: fromCustom,
        fromDefault: fromDefault,
        defaultsTo: defaultsTo,
        helpText: help,
        valueHelp: valueHelp,
        allowedHelp: allowedHelp,
        group: group,
        allowedValues: allowed?.toList(),
        customValidator: customValidator,
        mandatory: mandatory,
        hide: hide,
      ),
    );
    if (callback != null) {
      _optionCallbacks[name] = callback;
    }
  }

  @override
  void addMultiOption(
    final String name, {
    final String? abbr,
    final String? help,
    final String? valueHelp,
    final Iterable<String>? allowed,
    final Map<String, String>? allowedHelp,
    final Iterable<String>? defaultsTo,
    @Deprecated('Use parse results instead')
    final void Function(List<String>)? callback,
    final bool splitCommas = true,
    final bool hide = false,
    final List<String> aliases = const [],
    final String? envName,
    final String? configKey,
    final List<String>? Function(Configuration cfg)? fromCustom,
    final List<String> Function()? fromDefault,
    final OptionGroup? group,
    final void Function(List<String> value)? customValidator,
    final bool mandatory = false,
  }) {
    if (splitCommas) {
      _addOption(
        MultiStringOption(
          argName: name,
          argAliases: aliases,
          argAbbrev: abbr,
          envName: envName,
          configKey: configKey,
          fromCustom: fromCustom,
          fromDefault: fromDefault,
          defaultsTo: defaultsTo?.toList(),
          helpText: help,
          valueHelp: valueHelp,
          allowedHelp: allowedHelp,
          group: group,
          allowedValues: allowed?.toList(),
          customValidator: customValidator,
          mandatory: mandatory,
          hide: hide,
        ),
      );
    } else {
      _addOption(
        MultiStringOption.noSplit(
          argName: name,
          argAliases: aliases,
          argAbbrev: abbr,
          envName: envName,
          configKey: configKey,
          fromCustom: fromCustom,
          fromDefault: fromDefault,
          defaultsTo: defaultsTo?.toList(),
          helpText: help,
          valueHelp: valueHelp,
          allowedHelp: allowedHelp,
          group: group,
          allowedValues: allowed?.toList(),
          customValidator: customValidator,
          mandatory: mandatory,
          hide: hide,
        ),
      );
    }
    if (callback != null) {
      _multiOptionCallbacks[name] = callback;
    }
  }

  void _addOption(final OptionDefinition opt) {
    _optionDefinitions.add(opt);
    // added continuously to the parser so separators are placed correctly:
    addOptionsToParser([opt], _parser);
  }

  @override
  void addSeparator(final String text) => parser.addSeparator(text);

  @override
  ConfigResults parse(
    final Iterable<String> args, {
    final Map<String, String>? env,
    final ConfigurationBroker? configBroker,
    final Map<OptionDefinition, Object?>? presetValues,
  }) {
    validateOptions(_optionDefinitions);

    final argResults = parser.parse(args);

    final configuration = Configuration.resolve(
      options: _optionDefinitions,
      argResults: argResults,
      env: env,
      configBroker: configBroker,
      presetValues: presetValues,
      ignoreUnexpectedPositionalArgs: true,
    );

    if (configuration.errors.isNotEmpty) {
      throw UsageException(
        configuration.errors.join('\n'),
        usage,
      );
    }

    _invokeCallbacks(configuration);

    return ConfigResults(
      configuration,
      argResults.arguments,
      argResults.rest,
    );
  }

  void _invokeCallbacks(final Configuration cfg) {
    for (final entry in _flagCallbacks.entries) {
      entry.value(cfg.findValueOf<bool>(argName: entry.key) ?? false);
    }
    for (final entry in _optionCallbacks.entries) {
      entry.value(cfg.findValueOf<String>(argName: entry.key));
    }
    for (final entry in _multiOptionCallbacks.entries) {
      entry.value(cfg.findValueOf<List<String>>(argName: entry.key) ?? []);
    }
  }

  @override
  String get usage => parser.usage;

  @override
  int? get usageLineLength => parser.usageLineLength;

  @override
  dynamic defaultFor(final String option) => parser.defaultFor(option);

  @override
  @Deprecated('Use defaultFor instead.')
  dynamic getDefault(final String option) => parser.getDefault(option);

  @override
  Option? findByAbbreviation(final String abbr) =>
      parser.findByAbbreviation(abbr);

  @override
  Option? findByNameOrAlias(final String name) =>
      parser.findByNameOrAlias(name);

  @override
  bool get allowTrailingOptions => parser.allowTrailingOptions;

  @override
  bool get allowsAnything => parser.allowsAnything;

  @override
  ArgParser addCommand(final String name, [final ArgParser? parser]) {
    throw UnsupportedError('addCommand is not supported');
  }

  @override
  Map<String, ArgParser> get commands => parser.commands;

  @override
  @Deprecated('Use optionDefinitions instead.')
  Map<String, Option> get options => parser.options;
}

/// A wrapper around a [Configuration] object that implements the [ArgResults]
/// interface. This is returned by the [ConfigParser.parse] method.
///
/// This is backwards compatible with [ArgResults] except for the name and
/// command properties, which are always null since commands are not supported.
class ConfigResults implements ArgResults {
  final Configuration _configuration;

  ConfigResults(
    this._configuration,
    this.arguments,
    this.rest,
  );

  /// The original arguments that were parsed.
  @override
  final List<String> arguments;

  /// The remaining command-line arguments that were not parsed.
  @override
  final List<String> rest;

  /// The name of the command for which these options are parsed.
  /// Currently always null.
  @override
  String? get name => null;

  /// The name of the command for which these options are parsed.
  /// Currently always null.
  @override
  ArgResults? get command => null;

  @override
  dynamic operator [](final String name) {
    final option = _configuration.findOption(argName: name);
    if (option == null) {
      throw ArgumentError('No arg option named "--$name".');
    }
    return _configuration.optionalValue(option);
  }

  @override
  String? option(final String name) {
    final option = _configuration.findOption(argName: name);
    if (option == null) {
      throw ArgumentError('No arg option named "--$name".');
    }
    final value = _configuration.optionalValue(option);
    if (value is! String?) {
      throw ArgumentError('Arg option $name is not a string option.');
    }
    return value;
  }

  @override
  bool flag(final String name) {
    final option = _configuration.findOption(argName: name);
    if (option == null) {
      throw ArgumentError('No arg flag named "--$name".');
    }
    final value = _configuration.optionalValue(option);
    if (value is! bool) {
      throw ArgumentError('Arg flag $name is not a boolean flag.');
    }
    return value;
  }

  @override
  List<String> multiOption(final String name) {
    final option = _configuration.findOption(argName: name);
    if (option == null) {
      throw ArgumentError('No arg option named "--$name".');
    }
    final value = _configuration.optionalValue(option);
    if (value is! List<String>) {
      throw ArgumentError('Arg option $name is not a multi-string option.');
    }
    return value;
  }

  /// The arg names of the available options,
  /// i.e. the ones that have a value.
  /// Options that do not have arg names are omitted.
  @override
  Iterable<String> get options {
    return _configuration
        .optionsWhereSource((final source) => source != ValueSourceType.noValue)
        .map((final o) => o.option.argName)
        .whereType<String>();
  }

  /// Returns `true` if the option with [name] was parsed from an actual
  /// argument.
  @override
  bool wasParsed(final String name) {
    final option = _configuration.findOption(argName: name);
    if (option == null) {
      throw ArgumentError('Could not find an arg option named "--$name".');
    }
    final sourceType = _configuration.valueSourceType(option);
    return sourceType == ValueSourceType.arg;
  }
}
