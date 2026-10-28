import 'dart:async' show FutureOr;

import '../../config/arg_parser/arg_parser.dart'
    show
        ArgParseResult,
        DoubleDashHandling,
        ScanMode,
        optionAwaitingValue,
        scanAndParseCommands,
        unknownSubcommandErrorPrefix;
import '../../config/config.dart'
    show
        CommandDefinition,
        CompletionCandidate,
        CompletionContext,
        CompletionResult,
        ConfigOptionBase,
        FlagOption,
        MultiOption,
        MutuallyExclusive,
        OptionDefinition,
        ParsedArgs;
import 'completion_protocol.dart';

/// Computes the completion candidates for a partial command line,
/// using the command tree and option definitions of a root command.
///
/// The partial command line is parsed with the regular argument parser,
/// so the same rules apply as when running the command line: persistent
/// options, option aliases and abbreviations, `--option=value`, `--`, etc.
///
/// The engine never throws; on any error it responds with
/// [CompletionDirective.error].
class CompletionEngine {
  final CommandDefinition<OptionDefinition> rootCommand;

  /// See `CommandRunner.ignoreUnexpectedPositionalArgs`.
  final bool ignoreUnexpectedPositionalArgs;

  /// Receives a diagnostic message when a completion request fails.
  final void Function(Object error, StackTrace stackTrace)? onError;

  const CompletionEngine(
    this.rootCommand, {
    this.ignoreUnexpectedPositionalArgs = false,
    this.onError,
  });

  /// Completes the last of [words], the (possibly empty) word being typed,
  /// given the preceding words on the command line.
  ///
  /// [words] does not include the executable name.
  ///
  /// [environment] is not used by the engine itself; it is made available
  /// to custom `ConfigOptionBase.complete` implementations as
  /// `CompletionContext.environment`.
  Future<CompletionResponse> complete(
    final List<String> words, {
    final Map<String, String> environment = const {},
  }) async {
    try {
      return await _complete(words, environment);
    } catch (e, s) {
      onError?.call(e, s);
      return const CompletionResponse.error();
    }
  }

  /// A word no user types, appended to the preceding words to find out from
  /// the parser whether the word being completed is the value of an option.
  static const _sentinel = '\u0000<word-to-complete>\u0000';

  Future<CompletionResponse> _complete(
    final List<String> allWords,
    final Map<String, String> environment,
  ) async {
    final words = allWords.isEmpty ? const [''] : allWords;
    final current = words.last;
    final preceding = words.sublist(0, words.length - 1);

    final parsed = scanAndParseCommands(
      [...preceding, _sentinel],
      rootCommand: rootCommand,
      scanMode: ScanMode(
        doubleDashHandling: ignoreUnexpectedPositionalArgs
            ? DoubleDashHandling.passThroughRest
            : DoubleDashHandling.noSpecialHandling,
      ),
    );
    final chain = parsed.toList();
    final line = _CommandLine(
      chain: chain,
      preceding: preceding,
      environment: environment,
    );

    // After `--`, nothing is parsed; let the shell complete files.
    if (line.leaf.unparsedArgs.contains(_sentinel)) {
      return const CompletionResponse.files();
    }

    // The word being completed is the value of the preceding option.
    final valueOption = _optionAwaitingValue(line);
    if (valueOption != null) {
      return _completeOptionValue(line, valueOption, current);
    }

    // The word being completed is an option with an attached value:
    // `--option=val` or `-o=val`. The response contains the bare values,
    // the shell scripts re-attach the option prefix.
    if (current.startsWith('-') && current.contains('=')) {
      final equals = current.indexOf('=');
      final option = _findOptionBySpelling(line, current.substring(0, equals));
      if (option == null) return const CompletionResponse.nothing();
      return _completeOptionValue(line, option, current.substring(equals + 1));
    }

    if (current.startsWith('-')) {
      return _completeOptionNames(line, current);
    }

    if (line.leafCommand.subcommands.isNotEmpty) {
      // After an unknown subcommand word, no subcommand is valid anymore.
      if (line.hasRejectedSubcommand) return const CompletionResponse.nothing();
      return _completeSubcommands(line.leafCommand, current);
    }

    return _completePositional(line, current);
  }

  /// The option whose value is the word being completed, if any.
  ConfigOptionBase? _optionAwaitingValue(final _CommandLine line) {
    for (final result in line.chain) {
      for (final entry in result.regularOptions.entries) {
        if (entry.value == _sentinel) return entry.key;
      }
      for (final entry in result.multiOptions.entries) {
        if (entry.value.contains(_sentinel)) return entry.key;
      }
    }

    // The parser may have consumed the sentinel as the value of an option
    // without recording it, e.g. for an option specified more than once.
    // In that case the sentinel was not treated as a word.
    final leaf = line.leaf;
    final isWord =
        leaf.positionalWords.contains(_sentinel) ||
        leaf.errors.any((final error) => error.contains(_sentinel));
    if (isWord || line.preceding.isEmpty) return null;

    final spelling = optionAwaitingValue(line.preceding.last);
    if (spelling == null) return null;
    final option = _findOptionBySpelling(line, spelling);
    return option is FlagOption ? null : option;
  }

  /// Finds the option visible on the leaf command that is spelled
  /// `--name`, `--alias`, or `-x`.
  ConfigOptionBase? _findOptionBySpelling(
    final _CommandLine line,
    final String spelling,
  ) {
    for (final option in line.visibleOptions) {
      if (spelling.startsWith('--')) {
        final name = spelling.substring(2);
        if (option.argName == name) return option;
        if (option.argAliases?.contains(name) == true) return option;
        if (option is FlagOption && name == 'no-${option.argName}') {
          return option;
        }
      } else if (spelling.length == 2 && spelling.startsWith('-')) {
        if (option.argAbbrev == spelling[1]) return option;
      }
    }
    return null;
  }

  Future<CompletionResponse> _completeOptionValue(
    final _CommandLine line,
    final ConfigOptionBase option,
    final String word,
  ) async {
    // Complete the last element of a multi-value option word, e.g. `a,b<TAB>`.
    var prefix = '';
    var elementWord = word;
    if (option is MultiOption) {
      final separator = option.multiParser.separator;
      if (separator is String && separator.isNotEmpty) {
        final index = word.lastIndexOf(separator);
        if (index >= 0) {
          prefix = word.substring(0, index + separator.length);
          elementWord = word.substring(index + separator.length);
        }
      }
    }

    final context = CompletionContext(
      wordToComplete: elementWord,
      precedingWords: line.preceding,
      commands: line.commands,
      parsedArgs: _ChainParsedArgs(line.chain),
      environment: line.environment,
    );

    final FutureOr<CompletionResult> pending = option.complete(context);
    final result = pending is Future<CompletionResult>
        ? await pending
        : pending;
    return CompletionResponse.fromResult(result, prefix: prefix);
  }

  CompletionResponse _completeOptionNames(
    final _CommandLine line,
    final String current,
  ) {
    final includeShort = !current.startsWith('--');
    final candidates = <CompletionCandidate>[];

    for (final option in line.visibleOptions) {
      final name = option.argName;
      if (name == null || option.hide) continue;
      if (option is! MultiOption && line.wasGiven(option)) continue;
      if (line.isExcluded(option)) continue;

      final description = _firstLine(option.helpText);
      candidates.add(CompletionCandidate('--$name', description: description));
      if (option is FlagOption &&
          option.negatable &&
          !option.hideNegatedUsage) {
        candidates.add(
          CompletionCandidate('--no-$name', description: description),
        );
      }
      final abbrev = option.argAbbrev;
      if (includeShort && abbrev != null) {
        candidates.add(
          CompletionCandidate('-$abbrev', description: description),
        );
      }
    }

    // Subcommands spelled like options, e.g. `--version`.
    for (final subcommand in line.leafCommand.subcommands) {
      if (subcommand.usageDefinition.hidden) continue;
      final description = _firstLine(subcommand.usageDefinition.description);
      for (final spelling in [subcommand.name, ...subcommand.aliases.aliases]) {
        if (!spelling.startsWith('-')) continue;
        if (!includeShort && !spelling.startsWith('--')) continue;
        candidates.add(CompletionCandidate(spelling, description: description));
      }
    }

    return CompletionResponse(
      _matching(candidates, current),
      directive: CompletionDirective.noFileCompletion,
    );
  }

  CompletionResponse _completeSubcommands(
    final CommandDefinition command,
    final String current,
  ) {
    final candidates = [
      for (final subcommand in command.subcommands)
        if (!subcommand.usageDefinition.hidden &&
            !subcommand.name.startsWith('-'))
          CompletionCandidate(
            subcommand.name,
            description: _firstLine(subcommand.usageDefinition.description),
          ),
    ];
    return CompletionResponse(
      _matching(candidates, current),
      directive: CompletionDirective.noFileCompletion,
    );
  }

  Future<CompletionResponse> _completePositional(
    final _CommandLine line,
    final String current,
  ) async {
    final index = line.leaf.positionalWords
        .where((final word) => word != _sentinel)
        .length;
    for (final option in line.leafCommand.options) {
      if (option.option.argPos == index) {
        if (line.isExcluded(option.option)) {
          return const CompletionResponse.nothing();
        }
        return _completeOptionValue(line, option.option, current);
      }
    }
    return ignoreUnexpectedPositionalArgs
        ? const CompletionResponse.files()
        : const CompletionResponse.nothing();
  }

  static List<CompletionCandidate> _matching(
    final List<CompletionCandidate> candidates,
    final String prefix,
  ) {
    return [
      for (final candidate in candidates)
        if (candidate.value.startsWith(prefix)) candidate,
    ];
  }

  static String? _firstLine(final String? text) {
    if (text == null) return null;
    final line = text.trim().split('\n').first.trim();
    return line.isEmpty ? null : line;
  }
}

/// The parsed state of the command line preceding the word being completed.
class _CommandLine {
  final List<ArgParseResult> chain;
  final List<String> preceding;
  final Map<String, String> environment;

  _CommandLine({
    required this.chain,
    required this.preceding,
    required this.environment,
  });

  ArgParseResult get leaf => chain.last;

  CommandDefinition get leafCommand => _commandOf(leaf);

  List<CommandDefinition> get commands => [
    for (final result in chain) _commandOf(result),
  ];

  /// The options that can be given at the leaf command: its own options
  /// and the persistent options of it and its ancestors.
  Iterable<ConfigOptionBase> get visibleOptions sync* {
    final seen = <ConfigOptionBase>{};
    for (final command in commands) {
      for (final option in command.persistentOptions) {
        if (seen.add(option.option)) yield option.option;
      }
    }
    for (final option in leafCommand.options) {
      if (seen.add(option.option)) yield option.option;
    }
  }

  bool wasParsed(final ConfigOptionBase option) {
    return chain.any(
      (final result) =>
          result.flagOptions.containsKey(option) ||
          result.regularOptions.containsKey(option) ||
          result.multiOptions.containsKey(option),
    );
  }

  /// Whether [option] was given on the command line, by name or as a
  /// positional argument.
  bool wasGiven(final ConfigOptionBase option) {
    if (wasParsed(option)) return true;
    final argPos = option.argPos;
    if (argPos == null) return false;
    final positionalCount = leaf.positionalWords
        .where((final word) => word != CompletionEngine._sentinel)
        .length;
    return argPos < positionalCount;
  }

  /// Whether [option] can no longer be given because another option of its
  /// [MutuallyExclusive] group was given on the command line.
  bool isExcluded(final ConfigOptionBase option) {
    final group = option.group;
    if (group is! MutuallyExclusive) return false;
    return visibleOptions.any(
      (final other) =>
          other != option && other.group == group && wasGiven(other),
    );
  }

  /// Whether a preceding word was rejected as an unknown subcommand
  /// of the leaf command.
  bool get hasRejectedSubcommand {
    final rejected = leaf.errors.where(
      (final error) => error.startsWith(unknownSubcommandErrorPrefix),
    );
    return rejected.any(
      (final error) => !error.contains(CompletionEngine._sentinel),
    );
  }

  static CommandDefinition _commandOf(final ArgParseResult result) {
    final command = result.command;
    if (command == null) throw StateError('ArgParseResult.command is null');
    return command;
  }
}

/// The parsed arguments of all commands on the command line, as one view.
class _ChainParsedArgs implements ParsedArgs {
  final List<ArgParseResult> _chain;

  _ChainParsedArgs(this._chain);

  @override
  bool wasParsed(final ConfigOptionBase option) {
    return _chain.any(
      (final result) =>
          result.flagOptions.containsKey(option) ||
          result.regularOptions.containsKey(option) ||
          result.multiOptions.containsKey(option),
    );
  }

  @override
  bool flag(final FlagOption option) {
    for (final result in _chain) {
      final value = result.flagOptions[option];
      if (value != null) return value;
    }
    throw StateError('Flag ${option.argName} not found');
  }

  @override
  String option(final ConfigOptionBase option) {
    for (final result in _chain) {
      final value = result.regularOptions[option];
      if (value != null && value != CompletionEngine._sentinel) return value;
    }
    throw StateError('Option ${option.argName} not found');
  }

  @override
  List<String> multiOption(final MultiOption option) {
    for (final result in _chain) {
      final values = result.multiOptions[option];
      if (values != null) {
        return values
            .where((final value) => value != CompletionEngine._sentinel)
            .toList();
      }
    }
    throw StateError('Multi-option ${option.argName} not found');
  }

  @override
  List<String> get rest {
    final leaf = _chain.last;
    return [
      ...leaf.positionalWords,
      ...leaf.unparsedArgs,
    ].where((final word) => word != CompletionEngine._sentinel).toList();
  }

  @override
  List<String> get parseErrors => [
    for (final result in _chain)
      for (final error in result.errors)
        if (!error.contains(CompletionEngine._sentinel)) error,
  ];
}
