import '../config.dart'
    show
        ConfigOptionBase,
        FlagOption,
        MultiOption,
        OptionDefinition,
        CommandDefinitionError,
        validateOptions;
import 'command_definition.dart';
import 'parser_settings.dart';
import 'scanner.dart';
import 'suggestions.dart';

/// The start of the [ArgParseResult.errors] message recorded when a word
/// is not a known subcommand of a command that has subcommands.
const String unknownSubcommandErrorPrefix = 'Unknown subcommand: ';

/// Scans the arguments and parses them into an [ArgParseResult]
/// corresponding to a single set of options.
///
/// Does not handle subcommands.
/// Usage problems are recorded on [ArgParseResult.errors] and parsing
/// continues. Invalid option definitions still throw.
ArgParseResult<O> scanAndParseArgs<O extends OptionDefinition>(
  final Iterable<String> args, {
  required final Iterable<O> options,
  final ParserSettings settings = const ParserSettings(),
}) {
  validateOptions(options);

  final scannedArgs = scanArgs(args).toList();

  return _parseArgs(
    _ArgCursor(scannedArgs),
    options: options,
    settings: settings,
  );
}

/// Scans the arguments and parses them into an [ArgParseResult],
/// treating the args as a command line potentially containing subcommands.
///
/// A subcommand whose name or alias uses option syntax (`--version`, `-v`)
/// is considered an "action option". It is run as a command although it has
/// the name syntax of an option.
///
/// Usage problems are recorded on the [ArgParseResult] for the command
/// whose arguments contained them, and parsing continues.
/// Invalid command or option definitions still throw.
ArgParseResult<O> scanAndParseCommands<O extends OptionDefinition>(
  final Iterable<String> args, {
  required final CommandDefinition<O> rootCommand,
  final ParserSettings settings = const ParserSettings(),
}) {
  _validateCommandsAndOptions(rootCommand);

  final scannedArgs = scanArgs(args).toList();

  return _parseArgs(
    _ArgCursor(scannedArgs),
    command: rootCommand,
    settings: settings,
  );
}

/// Represents the parsed result for a command / subcommand on a command line.
///
/// An instance is a node in a linked list of subcommands.
/// The first node is the "root" (typically the executed program).
/// The last node is the "leaf" (the last subcommand on the command line).
class ArgParseResult<O extends OptionDefinition> {
  final CommandDefinition<O>? command;
  final ArgParseResult? parent;
  ArgParseResult? child;

  final Map<FlagOption, bool> flagOptions = <FlagOption, bool>{};
  final Map<ConfigOptionBase, String> regularOptions =
      <ConfigOptionBase, String>{};
  final Map<MultiOption, List<String>> multiOptions =
      <MultiOption, List<String>>{};
  final List<String> positionalWords = <String>[];
  final List<String> unparsedArgs = <String>[];

  /// Usage errors found while parsing this command's arguments.
  final List<String> errors = <String>[];

  ArgParseResult({this.command, this.parent});

  Iterator<ArgParseResult> get iterator => _ArgParseResultIterator(this);

  List<ArgParseResult> toList() =>
      Iterable.withIterator(() => iterator).toList();
}

class _ArgParseResultIterator implements Iterator<ArgParseResult> {
  bool _initial = true;

  _ArgParseResultIterator(final ArgParseResult initial) : current = initial;

  @override
  ArgParseResult current;

  @override
  bool moveNext() {
    if (_initial) {
      _initial = false;
      return true;
    }
    final child = current.child;
    if (child == null) return false;
    current = child;
    return true;
  }
}

/// Walks scanned arguments one token at a time.
class _ArgCursor {
  final List<ScannedArg> _args;
  int _argIndex = 0;
  int _tokenIndex = -1;

  _ArgCursor(this._args);

  bool moveNext() {
    if (_argIndex >= _args.length) return false;

    final nextToken = _tokenIndex + 1;
    if (nextToken < _args[_argIndex].tokens.length) {
      _tokenIndex = nextToken;
      return true;
    }

    final nextArg = _argIndex + 1;
    if (nextArg >= _args.length) return false;
    _argIndex = nextArg;
    _tokenIndex = 0;
    return true;
  }

  Token get current => _args[_argIndex].tokens[_tokenIndex];

  /// Whether the next token was cut from the same command-line argument.
  bool get nextContinuesRaw =>
      _argIndex < _args.length &&
      _tokenIndex + 1 < _args[_argIndex].tokens.length;

  bool get hasNext => nextContinuesRaw || _argIndex + 1 < _args.length;

  Token get peek => nextContinuesRaw
      ? _args[_argIndex].tokens[_tokenIndex + 1]
      : _args[_argIndex + 1].tokens.first;

  /// Drops later tokens cut from the current command-line argument.
  void skipFollowingRawContinuation() {
    _tokenIndex = _args[_argIndex].tokens.length - 1;
  }

  /// The original command-line argument for [current].
  String takeCurrentRaw() {
    final raw = _args[_argIndex].raw;
    skipFollowingRawContinuation();
    return raw;
  }

  /// Each command-line argument after the current one, in order.
  List<String> takeRemainingRaw() {
    final rest = <String>[
      for (var i = _argIndex + 1; i < _args.length; i++) _args[i].raw,
    ];
    _argIndex = _args.length;
    return rest;
  }
}

/// Reads the value for an option that takes one.
///
/// A separate following argument is taken whole, including values that start
/// with a hyphen (`--number -123`). A value attached with `=` is the attached
/// text only.
///
/// Returns null when no value is present. A cluster tail that is not an
/// attached `=` value is skipped, because those letters are not separate
/// options and are not a value either.
String? _readOptionValue(final _ArgCursor scannedArgs) {
  if (!scannedArgs.hasNext) return null;
  final next = scannedArgs.peek;
  if (scannedArgs.nextContinuesRaw) {
    if (next is WordToken) {
      scannedArgs.moveNext();
      return next.string;
    }
    scannedArgs.skipFollowingRawContinuation();
    return null;
  }
  scannedArgs.moveNext();
  return scannedArgs.takeCurrentRaw();
}

ArgParseResult<O> _parseArgs<O extends OptionDefinition>(
  final _ArgCursor scannedArgs, {
  final CommandDefinition<O>? command,
  final Iterable<O>? options,
  final ArgParseResult? parent,
  final Map<ConfigOptionBase, ArgParseResult<O>>? inheritedPersistentOwners,
  required final ParserSettings settings,
}) {
  final result = ArgParseResult<O>(command: command, parent: parent);
  var rejectedSubcommand = false;

  final persistentOwners = <ConfigOptionBase, ArgParseResult<O>>{
    ...?inheritedPersistentOwners,
    if (command != null) ...{
      for (final option in command.allOptions(onlyPersistent: true))
        option.option: result,
    },
  };

  final allOptions = [
    ...?command?.options,
    ...?options,
    ...persistentOwners.keys,
  ];

  final possibleOptionNames = <String, ConfigOptionBase>{};
  final possibleOptionAbbrevs = <String, ConfigOptionBase>{};
  for (final option in allOptions) {
    if (option.option.argName case final String name) {
      possibleOptionNames[name] = option.option;
      if (option.option case final FlagOption flag) {
        if (flag.negatable) {
          possibleOptionNames['no-$name'] = option.option;
        }
      }
    }
    if (option.option.argAliases case final List<String> aliases) {
      for (final alias in aliases) {
        possibleOptionNames[alias] = option.option;
      }
    }

    if (option.option.argAbbrev case final String abbrev) {
      possibleOptionAbbrevs[abbrev] = option.option;
    }
  }

  while (scannedArgs.moveNext()) {
    final arg = scannedArgs.current;

    switch (arg) {
      case LongOptionToken():
        final option = possibleOptionNames[arg.string];
        if (option != null) {
          _assignOption(
            result: result,
            target: persistentOwners[option] ?? result,
            option: option,
            scannedArgs: scannedArgs,
            name: arg.string,
            longOption: true,
          );
          break;
        }
        if (_enterMatchedSubcommand(
          result: result,
          scannedArgs: scannedArgs,
          command: command,
          persistentOwners: persistentOwners,
          settings: settings,
          name: '--${arg.string}',
        )) {
          return result;
        }
        result.errors.add('Unknown option: --${arg.string}');

      case ShortOptionToken():
        final option = possibleOptionAbbrevs[arg.string];
        if (option != null) {
          _assignOption(
            result: result,
            target: persistentOwners[option] ?? result,
            option: option,
            scannedArgs: scannedArgs,
            name: arg.string,
            longOption: false,
          );
          break;
        }
        if (_enterMatchedSubcommand(
          result: result,
          scannedArgs: scannedArgs,
          command: command,
          persistentOwners: persistentOwners,
          settings: settings,
          name: '-${arg.string}',
        )) {
          return result;
        }
        result.errors.add('Unknown option: -${arg.string}');

      case DoubleDashToken():
        if (settings.doubleDashHandling != DoubleDashHandling.passThroughRest) {
          result.errors.add('Unexpected value: ${arg.string}');
          break;
        }
        result.unparsedArgs.addAll(scannedArgs.takeRemainingRaw());

      case SingleDashToken():
        if (command != null && command.subcommands.isNotEmpty) {
          rejectedSubcommand = true;
          result.errors.add(
            _unknownSubcommandError(arg.string, command, settings),
          );
        } else {
          result.positionalWords.add(arg.string);
        }

      case ValueToken():
        result.errors.add('Unexpected value: ${arg.string}');

      case WordToken():
        if (_enterMatchedSubcommand(
          result: result,
          scannedArgs: scannedArgs,
          command: command,
          persistentOwners: persistentOwners,
          settings: settings,
          name: arg.string,
        )) {
          return result;
        }
        if (command != null && command.subcommands.isNotEmpty) {
          rejectedSubcommand = true;
          result.errors.add(
            _unknownSubcommandError(arg.string, command, settings),
          );
        } else {
          result.positionalWords.add(arg.string);
        }
    }
  }

  if (command != null &&
      command.subcommands.isNotEmpty &&
      !command.canRunAsLeafCommand &&
      result.child == null &&
      !rejectedSubcommand) {
    result.errors.add('A subcommand is required under ${command.name}');
  }

  return result;
}

String _unknownSubcommandError<O extends OptionDefinition>(
  final String name,
  final CommandDefinition<O> command,
  final ParserSettings settings,
) {
  final suggestions = similarCommandSuggestions(
    name,
    command.subcommands,
    settings.suggestionDistanceLimit,
  );
  return '$unknownSubcommandErrorPrefix"$name"$suggestions';
}

void _assignOption<O extends OptionDefinition>({
  required final ArgParseResult<O> result,
  required final ArgParseResult<O> target,
  required final ConfigOptionBase option,
  required final _ArgCursor scannedArgs,
  required final String name,
  required final bool longOption,
}) {
  final written = '${longOption ? '--' : '-'}$name';
  switch (option.option) {
    case final FlagOption flag:
      if (_recordIfSpecifiedMoreThanOnce(
        result,
        option,
        target.flagOptions.containsKey(option),
      )) {
        return;
      }
      target.flagOptions[flag] = longOption
          ? !_isNegatedFlag(flag, name)
          : true;

    case final MultiOption multiOption:
      final value = _readOptionValue(scannedArgs);
      if (value == null) {
        result.errors.add('Missing value for option: $written');
        return;
      }
      final values = target.multiOptions[multiOption] ?? <String>[];
      values.add(value);
      target.multiOptions[multiOption] = values;

    default:
      final duplicate = _recordIfSpecifiedMoreThanOnce(
        result,
        option,
        target.regularOptions.containsKey(option),
      );
      final value = _readOptionValue(scannedArgs);
      if (value == null) {
        result.errors.add('Missing value for option: $written');
        return;
      }
      if (!duplicate) {
        target.regularOptions[option] = value;
      }
  }
}

bool _isNegatedFlag(final FlagOption flag, final String name) {
  if (!flag.negatable) return false;
  final argName = flag.argName;
  return argName != null && name == 'no-$argName';
}

void _validateCommandsAndOptions<O extends OptionDefinition>(
  final CommandDefinition<O> command, {
  final List<OptionDefinition> inheritedPersistentOptions = const [],
}) {
  final visibleOptions = <OptionDefinition>[
    ...inheritedPersistentOptions,
    ...command.allOptions(),
  ];
  validateOptions(visibleOptions);

  _rejectPositionalPersistentOptions(command);

  final subcommands = command.subcommands;
  if (subcommands.isNotEmpty) {
    _rejectDuplicateSubcommandNames(command.name, subcommands);
    _rejectPositionalOptionsOnBranch(command);
    _rejectOptionLikeSubcommandCollisions(
      command.name,
      visibleOptions,
      subcommands,
    );
  }

  final persistentOptions = <OptionDefinition>[
    ...inheritedPersistentOptions,
    ...command.allOptions(onlyPersistent: true),
  ];
  for (final subcommand in subcommands) {
    _validateCommandsAndOptions(
      subcommand,
      inheritedPersistentOptions: persistentOptions,
    );
  }
}

void _rejectDuplicateSubcommandNames(
  final String commandName,
  final List<CommandDefinition> subcommands,
) {
  final names = <String>{};
  for (final subcommand in subcommands) {
    final name = subcommand.name;
    if (!names.add(name)) {
      throw CommandDefinitionError(
        subcommand,
        'Duplicate subcommand name: $name for command $commandName',
      );
    }
  }
}

/// Rejects a subcommand name or alias in option syntax that matches an
/// option visible on [commandName].
///
/// Visible options are the command's own options and every persistent option
/// inherited from its ancestors. A command may still define an option whose spelling
/// matches its own name: that option is parsed only after the command is
/// selected.
void _rejectOptionLikeSubcommandCollisions<O extends OptionDefinition>(
  final String commandName,
  final List<O> options,
  final List<CommandDefinition> subcommands,
) {
  final spellings = <String, OptionDefinition>{};
  for (final option in options) {
    final argName = option.option.argName;
    if (argName != null) {
      spellings['--$argName'] = option;
      if (option.option case final FlagOption flag when flag.negatable) {
        spellings['--no-$argName'] = option;
      }
    }
    if (option.option.argAliases case final List<String> aliases) {
      for (final alias in aliases) {
        spellings['--$alias'] = option;
      }
    }
    if (option.option.argAbbrev case final String abbrev) {
      spellings['-$abbrev'] = option;
    }
  }
  if (spellings.isEmpty) return;

  for (final subcommand in subcommands) {
    _rejectSubcommandSpelling(
      commandName,
      subcommand,
      subcommand.name,
      spellings,
      isAlias: false,
    );
    for (final alias in subcommand.aliasesDefinition.aliases) {
      _rejectSubcommandSpelling(
        commandName,
        subcommand,
        alias,
        spellings,
        isAlias: true,
      );
    }
  }
}

void _rejectSubcommandSpelling(
  final String commandName,
  final CommandDefinition subcommand,
  final String spelling,
  final Map<String, OptionDefinition> spellings, {
  required final bool isAlias,
}) {
  if (!_isOptionLikeCommandName(spelling)) return;
  final option = spellings[spelling];
  if (option == null) return;
  final kind = isAlias ? 'alias' : 'name';
  throw CommandDefinitionError(
    subcommand,
    'Subcommand $kind `$spelling` collides with ${option.option.qualifiedString()} '
    'for command $commandName',
  );
}

/// Whether [name] is a long option (`--version`) or a one-character short
/// option (`-v`), the spellings the parser can select as action options.
bool _isOptionLikeCommandName(final String name) {
  if (name.startsWith('--')) {
    return name.length > 2 && !name.contains('=');
  }
  return name.length == 2 && name.startsWith('-') && name[1] != '=';
}

void _rejectPositionalPersistentOptions<O extends OptionDefinition>(
  final CommandDefinition<O> command,
) {
  for (final option in command.persistentOptions) {
    if (option.option.argPos == null) continue;
    throw CommandDefinitionError(
      command,
      'Persistent options must not be positional: '
      '${option.option.qualifiedString()}.',
    );
  }
}

void _rejectPositionalOptionsOnBranch<O extends OptionDefinition>(
  final CommandDefinition<O> command,
) {
  for (final option in command.options) {
    if (option.option.argPos == null) continue;
    throw CommandDefinitionError(
      command,
      'Cannot define positional options on a command with subcommands: '
      '${option.option.qualifiedString()}.',
    );
  }
}

bool _recordIfSpecifiedMoreThanOnce(
  final ArgParseResult result,
  final ConfigOptionBase option,
  final bool alreadySpecified,
) {
  if (!alreadySpecified) return false;

  final name = option.argName;
  final label = name != null ? '--$name' : '-${option.argAbbrev}';
  result.errors.add('Option $label cannot be specified more than once');
  return true;
}

/// Selects the first subcommand whose name or alias is [name].
///
/// Action options call this with the option spelling (`--version`, `-v`)
/// after no defined option matched that spelling.
bool _enterMatchedSubcommand<O extends OptionDefinition>({
  required final ArgParseResult<O> result,
  required final _ArgCursor scannedArgs,
  required final CommandDefinition<O>? command,
  required final Map<ConfigOptionBase, ArgParseResult<O>> persistentOwners,
  required final ParserSettings settings,
  required final String name,
}) {
  final subcommands = command?.subcommands;
  if (subcommands == null || subcommands.isEmpty) return false;
  if (_matchSubcommand(subcommands, name)
      case final CommandDefinition subcommand) {
    result.child = _parseArgs(
      scannedArgs,
      command: subcommand,
      parent: result,
      inheritedPersistentOwners: persistentOwners,
      settings: settings,
    );
    return true;
  }
  return false;
}

CommandDefinition<O>? _matchSubcommand<O extends OptionDefinition>(
  final Iterable<CommandDefinition<O>> subcommands,
  final String name,
) {
  for (final subcommand in subcommands) {
    if (subcommand.name == name ||
        subcommand.aliasesDefinition.aliases.contains(name)) {
      return subcommand;
    }
  }
  return null;
}
