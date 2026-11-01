import 'package:args/args.dart' show ArgResults, ArgParser;

import 'arg_parser/arg_parser.dart' show scanAndParseArgs, ArgParseResult;
import 'arg_parser_bridge.dart' show OldParsedArgs, addOptionsToParser;
import 'options.dart'
    show
        OptionDefinition,
        validateOptions,
        ConfigOptionBase,
        FlagOption,
        MultiOption,
        OptionGroup;

/// Validates and prepares a set of options for a legacy [ArgParser].
void prepareOptionsForParsing(
  final Iterable<OptionDefinition> options,
  final ArgParser argParser,
) {
  final argNameOpts = validateOptions(options);
  addOptionsToParser(argNameOpts, argParser, addGroupSeparators: true);
}

/// Throws [FormatException] from [ArgParser.parse] if the argument parsing fails.
OldParsedArgs legacyParsedArgs(
  final List<OptionDefinition> options,
  final Iterable<String> args, {
  final bool allowTrailingOptions = false,
}) {
  final argNameOpts = options
      .where((final o) => o.option.argName != null)
      .toList();

  return OldParsedArgs(
    argNameOpts,
    args,
    allowTrailingOptions: allowTrailingOptions,
  );
}

OldParsedArgs legacyParsedArgsFromArgResults(final ArgResults argResults) {
  return OldParsedArgs.fromArgResults(argResults);
}

NewParsedArgs newParsedArgs(
  final Iterable<OptionDefinition> options,
  final Iterable<String> args,
) {
  return NewParsedArgs(scanAndParseArgs(args, options: options));
}

/// A proxy (wrapper) for the parsed command-line arguments for an individual
/// command/subcommand.
abstract interface class ParsedArgs {
  /// Returns `true` if the option was parsed from an actual argument.
  bool wasParsed(final ConfigOptionBase option);

  /// Returns the value of the specified parsed command-line flag.
  ///
  /// [option] must be a successfully parsed flag option,
  /// otherwise throws [StateError].
  bool flag(final FlagOption option);

  /// Returns the string value of the specified parsed command-line option.
  ///
  /// [option] must be a successfully parsed option,
  /// otherwise throws [StateError].
  String option(final ConfigOptionBase option);

  /// Returns the value list of the specified parsed command-line multi-option.
  ///
  /// [option] must be a successfully parsed multi-option,
  /// otherwise throws [StateError].
  List<String> multiOption(final MultiOption option);

  /// The remaining command-line arguments that were not parsed as options or
  /// flags.
  ///
  /// If `--` was used to separate the options from the remaining arguments,
  /// it will not be included in this list unless parsing stopped before the
  /// `--` was reached.
  List<String> get rest;

  /// Usage errors recorded while parsing these arguments, such as an unknown
  /// option. Empty when parsing succeeded.
  List<String> get parseErrors;
}

class NewParsedArgs implements ParsedArgs {
  final ArgParseResult _result;

  NewParsedArgs(final ArgParseResult result) : _result = result;

  @override
  bool wasParsed(final OptionDefinition option) {
    return _result.flagOptions.containsKey(option) ||
        _result.regularOptions.containsKey(option) ||
        _result.multiOptions.containsKey(option);
  }

  @override
  bool flag(final FlagOption option) {
    final value = _result.flagOptions[option];
    if (value == null) {
      throw StateError('Flag ${option.option.argName} not found');
    }
    return value;
  }

  @override
  String option(final OptionDefinition option) {
    final value = _result.regularOptions[option];
    if (value == null) {
      throw StateError('Option ${option.option.argName} not found');
    }
    return value;
  }

  @override
  List<String> multiOption(final MultiOption option) {
    final value = _result.multiOptions[option];
    if (value == null) {
      throw StateError('Multi-option ${option.option.argName} not found');
    }
    return value;
  }

  @override
  List<String> get rest {
    return [..._result.positionalWords, ..._result.unparsedArgs];
  }

  @override
  List<String> get parseErrors => _result.errors;
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
void addOptionsToReceiver(
  final Iterable<OptionDefinition> argNameOpts,
  final OptionReceiver receiver, {
  final bool addGroupSeparators = false,
}) {
  // plain option-addition without any group separator logic
  if (!addGroupSeparators) {
    for (final o in argNameOpts) {
      receiver.addOption(o.option);
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
    receiver.addOption(o.option);
  }

  // add all explicit groups (in order)
  optionGroups.forEach((final group, final groupedOptions) {
    // add the group-name-separator only if it has at least one visible option
    if (groupedOptions.any((final o) => !o.option.hide)) {
      receiver.addSeparator(group.name);
    }
    // add all options within this group (in order)
    for (final o in groupedOptions) {
      receiver.addOption(o.option);
    }
  });
}

abstract interface class OptionReceiver {
  void addSeparator(final String separator);

  void addOption(final OptionDefinition option);
}
