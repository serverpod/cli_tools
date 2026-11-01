import 'dart:math' as math;

import '../../config/config.dart'
    show
        ConfigOptionBase,
        FlagOption,
        MultiOption,
        MutuallyExclusive,
        MutuallyExclusiveMode,
        OptionDefinition;
import '../abstract_command.dart' show AbstractCommand;

/// Synopsis of [cmd].
///
/// Parent command names come first, then this command's positional options
/// in [ConfigOptionBase.argPos] order, then its persistent named options and
/// its own named options. An option with both a name and a position is shown
/// only in the positional slot. Optional tokens are wrapped in `[]`.
/// A mandatory mutually exclusive group is one `(a | b)` token.
/// A non-mandatory one is `[a | b]`.
///
/// A command with subcommands ends in `<subcommand> [arguments]`.
/// When [AbstractCommand.canRunAsLeafCommand] is set, a second `or:` line
/// omits that suffix.
String commandInvocationSynopsis(final AbstractCommand cmd) {
  final path = _commandPath(cmd);
  final tokens = _synopsisTokens(cmd);
  final leaf = [path, ...tokens].join(' ');
  if (cmd.subcommands.isEmpty) return leaf;

  final branch = [path, ...tokens, '<subcommand> [arguments]'].join(' ');
  if (!cmd.canRunAsLeafCommand) return branch;
  return '$branch\n   or: $leaf';
}

String _commandPath(final AbstractCommand cmd) {
  final parents = [cmd.name];
  var command = cmd;
  while (command.hasParent) {
    command = command.parent;
    parents.add(command.name);
  }
  return parents.reversed.join(' ');
}

/// Positional tokens, then named tokens, for options that can be passed
/// on the command line.
List<String> _synopsisTokens(final AbstractCommand command) {
  final options = [
    ...command.persistentOptions,
    ...command.options,
  ].where(_isCommandLineOption).toList();

  final groups = <MutuallyExclusive, List<OptionDefinition>>{};
  final ungrouped = <({int index, OptionDefinition option})>[];
  for (var i = 0; i < options.length; i++) {
    final option = options[i];
    final group = option.option.group;
    if (group is MutuallyExclusive) {
      groups.putIfAbsent(group, () => []).add(option);
    } else {
      ungrouped.add((index: i, option: option));
    }
  }

  final positional = <({int sortKey, String token})>[];
  final named = <({int sortKey, String token})>[];

  for (final entry in ungrouped) {
    final option = entry.option.option;
    final token = _bracketedToken(option);
    final argPos = option.argPos;
    if (argPos != null) {
      positional.add((sortKey: argPos, token: token));
    } else {
      named.add((sortKey: entry.index, token: token));
    }
  }

  for (final MapEntry(key: group, value: members) in groups.entries) {
    final token = _exclusiveGroupToken(
      members,
      mandatory: group.mode == MutuallyExclusiveMode.mandatory,
    );
    final positions = [
      for (final member in members)
        if (member.option.argPos case final int pos) pos,
    ];
    if (positions.isNotEmpty) {
      positional.add((sortKey: positions.reduce(math.min), token: token));
    } else {
      named.add((sortKey: options.indexOf(members.first), token: token));
    }
  }

  positional.sort((final a, final b) => a.sortKey.compareTo(b.sortKey));
  named.sort((final a, final b) => a.sortKey.compareTo(b.sortKey));
  return [...positional, ...named].map((final entry) => entry.token).toList();
}

bool _isCommandLineOption(final OptionDefinition option) {
  final opt = option.option;
  if (opt.hide) return false;
  return opt.argName != null || opt.argPos != null;
}

/// Long name, or the positional placeholder when [option] has [ConfigOptionBase.argPos].
String _synopsisSyntax(final ConfigOptionBase option) {
  final argPos = option.argPos;
  if (argPos != null) return '<${_valuePlaceholder(option)}>';

  final name = option.argName!;
  if (option is FlagOption) {
    if (option.negatable && !option.hideNegatedUsage) return '--[no-]$name';
    return '--$name';
  }
  return '--$name=<${_valuePlaceholder(option)}>';
}

String _valuePlaceholder(final ConfigOptionBase option) {
  final help = option.valueHelp;
  if (help != null && help.isNotEmpty) return help;
  return option.argName ?? 'arg${option.argPos}';
}

String _bracketedToken(final ConfigOptionBase option) {
  final syntax = _synopsisSyntax(option);
  final repeat = option is MultiOption;
  if (option.mandatory) return repeat ? '$syntax...' : syntax;
  return repeat ? '[$syntax]...' : '[$syntax]';
}

/// Positionals inside the group stay in [ConfigOptionBase.argPos] order,
/// then named alternatives in definition order.
String _exclusiveGroupToken(
  final List<OptionDefinition> members, {
  required final bool mandatory,
}) {
  final positional =
      members.where((final member) => member.option.argPos != null).toList()
        ..sort(
          (final a, final b) => a.option.argPos!.compareTo(b.option.argPos!),
        );
  final named = members.where((final member) => member.option.argPos == null);
  final ordered = [...positional, ...named];
  final body = ordered
      .map((final member) => _groupMemberSyntax(member.option))
      .join(' | ');
  return mandatory ? '($body)' : '[$body]';
}

String _groupMemberSyntax(final ConfigOptionBase option) {
  final syntax = _synopsisSyntax(option);
  return option is MultiOption ? '$syntax...' : syntax;
}
