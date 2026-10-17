import 'package:args/args.dart' show ArgResults, ArgParser;

import '../../config.dart';
import 'arg_parser/arg_parser.dart' show ArgParseResult, scanAndParseArgs;
import 'arg_parser_bridge.dart' show OldParsedArgs, addOptionsToParser;

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
}
