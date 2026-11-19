import 'package:args/args.dart';

import 'arg_parser_facade.dart';
import 'options.dart';

/// A ParsedArgs implementation for the old approach using ArgParser and ArgResults.
class OldParsedArgs implements ParsedArgs {
  late final ArgResults argResults;

  /// Throws [FormatException] from [ArgParser.parse] if the argument parsing fails.
  OldParsedArgs(
    final List<OptionDefinition> options,
    final Iterable<String> args, {
    final bool allowTrailingOptions = false,
  }) {
    final parser = ArgParser(allowTrailingOptions: allowTrailingOptions);
    addOptionsToParser(options, parser);
    argResults = parser.parse(args);
  }

  OldParsedArgs.fromArgResults(this.argResults);

  /// Returns `true` if the option with [name] was parsed from an actual
  /// argument.
  ///
  /// Returns `false` if it wasn't provided and the default value or no default
  /// value would be used instead.
  ///
  /// [name] must be a valid option name in the parser.
  @override
  bool wasParsed(final ConfigOptionBase option) {
    return argResults.wasParsed(_optionArgName(option));
  }

  /// Returns the parsed or default command-line flag named [name].
  ///
  /// [name] must be a valid flag name in the parser.
  @override
  bool flag(final FlagOption option) {
    return argResults.flag(_optionArgName(option));
  }

  /// Returns the parsed string value of the argument option named [name].
  ///
  /// [name] must be a valid option name in the parser.
  ///
  /// Throws [StateError] if the option was not parsed.
  @override
  String option(final OptionDefinition option) {
    return argResults.option(_optionArgName(option))!;
  }

  /// Returns the list of parsed (or default) command-line options for [name].
  ///
  /// [name] must be a valid option name in the parser.
  @override
  List<String> multiOption(final MultiOption option) {
    return argResults.multiOption(_optionArgName(option));
  }

  String _optionArgName(final OptionDefinition option) {
    final argName = option.option.argName;
    if (argName == null) {
      throw StateError('Option has no arg name: $option');
    }
    return argName;
  }

  /// The remaining command-line arguments that were not parsed as options or
  /// flags.
  ///
  /// If `--` was used to separate the options from the remaining arguments,
  /// it will not be included in this list unless parsing stopped before the
  /// `--` was reached.
  @override
  List<String> get rest {
    return argResults.rest;
  }

  /// The legacy parser throws instead of recording usage errors.
  @override
  List<String> get parseErrors => const [];
}

/// Returns the usage help text for these options.
String oldUsage(final Iterable<OptionDefinition> options) {
  final parser = ArgParser();
  final argOptions = options.where((final o) => o.option.argName != null);
  addOptionsToParser(
    argOptions,
    parser,
    addGroupSeparators: true,
    usageOnly: true,
  );
  return parser.usage;
}

void addOptionsToParser(
  final Iterable<OptionDefinition> argNameOpts,
  final ArgParser argParser, {
  final bool addGroupSeparators = false,
  final bool usageOnly = false,
}) {
  final receiver = _ArgParserOptionCollection(
    argParser,
    usageOnly: usageOnly,
  );
  addOptionsToReceiver(
    argNameOpts,
    receiver,
    addGroupSeparators: addGroupSeparators,
  );
}

class _ArgParserOptionCollection implements OptionReceiver {
  final ArgParser argParser;
  final bool usageOnly;

  _ArgParserOptionCollection(
    this.argParser, {
    required this.usageOnly,
  });

  @override
  void addSeparator(final String separator) {
    argParser.addSeparator(separator);
  }

  @override
  void addOption(final OptionDefinition option) {
    _addToArgParser(option, argParser, usageOnly: usageOnly);
  }
}

void _addToArgParser(
  final OptionDefinition option,
  final ArgParser argParser, {
  required final bool usageOnly,
}) {
  final opt = option.option;
  final argName = opt.argName;
  if (argName == null) {
    throw StateError("Can't add option without arg name to arg parser.");
  }

  switch (opt) {
    case FlagOption():
      argParser.addFlag(
        argName,
        abbr: opt.argAbbrev,
        help: _flagHelp(opt, usageOnly: usageOnly),
        defaultsTo: _flagDefault(opt, usageOnly: usageOnly),
        negatable: opt.negatable,
        hideNegatedUsage: opt.hideNegatedUsage,
        hide: opt.hide,
        aliases: opt.argAliases ?? const [],
      );

    case MultiOption():
      argParser.addMultiOption(
        argName,
        abbr: opt.argAbbrev,
        help: opt.helpText,
        valueHelp: opt.valueHelpString(),
        allowed: opt.allowedElementValues?.map(
          opt.multiParser.elementParser.format,
        ),
        allowedHelp: opt.allowedHelp,
        defaultsTo: _legacyMultiDefaults(opt, usageOnly: usageOnly),
        hide: opt.hide,
        splitCommas: opt.multiParser.separator == ',',
        aliases: opt.argAliases ?? const [],
      );

    default:
      argParser.addOption(
        argName,
        abbr: opt.argAbbrev,
        help: opt.helpText,
        valueHelp: opt.valueHelpString(),
        allowed: opt.allowedValues?.map(opt.valueParser.format),
        allowedHelp: opt.allowedHelp,
        defaultsTo: _legacyDefaultString(opt, usageOnly: usageOnly),
        mandatory: opt.mandatory,
        hide: opt.hide,
        aliases: opt.argAliases ?? const [],
      );
  }
}

/// Help text for a flag on the legacy parser.
///
/// [package:args] prints `(defaults to on)` from the boolean default and has
/// no slot for custom default text. Usage-only parsers put
/// [FlagOption.defaultValueHelp] in the help and omit that boolean line.
/// Parsers used to parse arguments keep [FlagOption.helpText] unchanged.
String? _flagHelp(final FlagOption opt, {required final bool usageOnly}) {
  final help = opt.helpText;
  if (!usageOnly) return help;
  final custom = opt.defaultValueHelp;
  if (custom == null) return help;
  final line = '(defaults to $custom)';
  if (help == null || help.isEmpty) return line;
  return '$help\n$line';
}

/// Boolean default stored on the legacy parser.
///
/// A usage-only parser passes null when custom default text is shown, so
/// [package:args] does not also print `(defaults to on)`. A parser that
/// reads arguments keeps the real boolean.
bool? _flagDefault(final FlagOption opt, {required final bool usageOnly}) {
  if (usageOnly && opt.defaultValueHelp != null) return null;
  return opt.defaultValue();
}

/// Default string stored on the legacy parser.
///
/// Allowed values are matched against the formatted default to mark it,
/// so a custom help string is used only when there is nothing to match.
/// That help string is usage text: parsers that read arguments store the
/// formatted value instead, so an omitted option does not come back as the
/// help text.
String? _legacyDefaultString(
  final ConfigOptionBase opt, {
  required final bool usageOnly,
}) {
  if (opt.allowedValues != null || opt.allowedHelp != null) {
    final value = opt.defaultValue();
    if (value == null) return null;
    return opt.valueParser.format(value);
  }
  if (!usageOnly) {
    final value = opt.defaultValue();
    if (value == null) return null;
    return opt.valueParser.format(value);
  }
  return opt.defaultValueString();
}

/// Default list stored on the legacy parser for a [MultiOption].
///
/// Same rule as [_legacyDefaultString]: custom help text is only stored on
/// a parser that exists to render usage.
Iterable<String>? _legacyMultiDefaults(
  final MultiOption opt, {
  required final bool usageOnly,
}) {
  final marksAllowed =
      opt.allowedElementValues != null || opt.allowedHelp != null;
  final help = opt.defaultValueHelp;
  if (usageOnly &&
      !marksAllowed &&
      help != null &&
      opt.defaultValue() != null) {
    return [help];
  }
  return opt.defaultValue()?.map(opt.multiParser.elementParser.format);
}
