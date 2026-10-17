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
}

/// Returns the usage help text for these options.
String oldUsage(final Iterable<OptionDefinition> options) {
  final parser = ArgParser();
  final argOptions = options.where((final o) => o.option.argName != null);
  addOptionsToParser(argOptions, parser, addGroupSeparators: true);
  return parser.usage;
}

/// Adds [argNameOpts] to [argParser].
///
/// When [addGroupSeparators] is `true`,
/// - options are grouped by [OptionGroup] and a
/// - separator with the group name is inserted
/// - before each group that has at least one visible option.
/// - Note:
///     - groupless options are added first in their original order
///     - relative order of all options within a group is preserved
///     - relative order of all groups is preserved
///
/// By default,
/// [addGroupSeparators] is `false` to ensure backwards compatibility.
void addOptionsToParser(
  final Iterable<OptionDefinition> argNameOpts,
  final ArgParser argParser, {
  final bool addGroupSeparators = false,
}) {
  // plain option-addition without any group separator logic
  if (!addGroupSeparators) {
    for (final o in argNameOpts) {
      _addToArgParser(o.option, argParser);
    }
    return;
  }

  // the following containers are ordered by default i.e.
  // preserves insertion-order:
  // - Map  : https://stackoverflow.com/q/79786585/10251345
  // - List : https://api.dart.dev/dart-core/List-class.html
  final optionGroups = <OptionGroup, List<OptionDefinition>>{};
  final grouplessOptions = <OptionDefinition>[];

  // gather all necessary option-group information
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

  // add all groupless-options first (in order)
  for (final o in grouplessOptions) {
    _addToArgParser(o.option, argParser);
  }

  // add all explicit groups (in order)
  optionGroups.forEach((final group, final groupedOptions) {
    // add the group-name-separator only if it has at least one visible option
    if (groupedOptions.any((final o) => !o.option.hide)) {
      argParser.addSeparator(group.name);
    }
    // add all options within this group (in order)
    for (final o in groupedOptions) {
      _addToArgParser(o.option, argParser);
    }
  });
}

void _addToArgParser(final OptionDefinition option, final ArgParser argParser) {
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
        help: opt.helpText,
        defaultsTo: opt.defaultValue(),
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
        defaultsTo: opt.defaultValue()?.map(
          opt.multiParser.elementParser.format,
        ),
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
        defaultsTo: opt.defaultValueString(),
        mandatory: opt.mandatory,
        hide: opt.hide,
        aliases: opt.argAliases ?? const [],
      );
  }
}
