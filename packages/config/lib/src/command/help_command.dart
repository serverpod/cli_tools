import 'dart:async' show FutureOr;

import 'package:collection/collection.dart';

import '../config/config.dart'
    show OptionDefinition, CommandUsageDefinition, CommandAliasesDefinition;
import 'command.dart' show Command;
import 'command_context.dart' show CommandContext;
import 'command_runner.dart';

/// Standard built-in help command.
///
/// This command is hidden (not shown in the help output) but automatically
/// added as subcommand to all commands that have subcommands.
/// This enables the syntax `help build` for all commands in the command tree.
///
/// When specified last on the command line it will show the help for the prior
/// command, e.g. `build help`. By extending this class and overriding [run]
/// this help output can be customized. Some command systems provide a more
/// extensive user guide when help is specified last in this way.
class HelpCommand<T> extends Command<OptionDefinition, T> {
  @override
  final String name = 'help';

  @override
  final CommandUsageDefinition usageDefinition = const CommandUsageDefinition(
    description: 'Show help for a command.',
    hidden: true,
  );

  @override
  final CommandAliasesDefinition aliases = const CommandAliasesDefinition();

  HelpCommand();

  @override
  bool get runStandalone => true;

  /// Help is shown for partial command lines, e.g. when the preceding
  /// command is missing mandatory options or a subcommand.
  @override
  bool get acceptsPartialCommandLine => true;

  @override
  bool get canRunAsLeafCommand => true;

  /// The sibling commands of this help command, i.e. the commands it can
  /// show help for, wrapped so that `help <command>` shows usage.
  @override
  List<Command<OptionDefinition, T>> get subcommands => _helpSubcommands(
    parent.subcommands.whereNot((final command) => command.name == name),
  );

  @override
  FutureOr<T?> run(final CommandContext context) {
    // If run is called, this is the last command on the command line -
    // show the help for the previous command.
    final parent = context.prev;
    if (parent == null) throw StateError('A parent command is expected');
    _printCommandUsage(parent);
    return null;
  }
}

/// Wraps the visible [commands] in [_HelpSubcommand]s.
List<Command<OptionDefinition, T>> _helpSubcommands<T>(
  final Iterable<Command<OptionDefinition, T>> commands,
) {
  return commands
      .whereNot((final command) => command.usageDefinition.hidden)
      .map((final command) => _HelpSubcommand(subcommand: command))
      .toList();
}

/// Wrapper that represents each actual subcommand but produces its usage help
/// instead of running it. By representing each subcommand to the parser,
/// it will correctly validate the command line with a 'help' command.
class _HelpSubcommand<T> extends Command<OptionDefinition, T> {
  @override
  String get name => _subcommand.name;

  @override
  CommandUsageDefinition get usageDefinition => _subcommand.usageDefinition;

  @override
  CommandAliasesDefinition get aliases => _subcommand.aliases;

  @override
  List<OptionDefinition> get persistentOptions => _subcommand.persistentOptions;

  @override
  List<OptionDefinition> get options => _subcommand.options;

  /// The subcommands are wrapped as well, so that `help a b` shows the help
  /// for the nested command `b` instead of running it.
  @override
  List<Command<OptionDefinition, T>> get subcommands =>
      _helpSubcommands(_subcommand.subcommands);

  /// The usage of the represented command, as shown by its `--help` option.
  @override
  String get usage => _subcommand.usage;

  final Command<OptionDefinition, T> _subcommand;

  _HelpSubcommand({
    required final Command<OptionDefinition, T> subcommand,
  }) : _subcommand = subcommand;

  @override
  bool get runStandalone => true;

  /// Help is shown for a command whether or not it requires a subcommand.
  @override
  bool get canRunAsLeafCommand => true;

  /// The represented command's options are mirrored for parsing but need
  /// not be complete or valid to show its usage.
  @override
  bool get acceptsPartialCommandLine => true;

  @override
  FutureOr<T?> run(final CommandContext context) {
    _printCommandUsage(context);
    return null;
  }
}

void _printCommandUsage(final CommandContext context) {
  final rootCommand = context.root().command;
  if (rootCommand is! CommandRunner) {
    throw StateError(
      'Help command requires the root command to be a CommandRunner'
      " but it's a ${rootCommand.runtimeType}.",
    );
  }
  rootCommand.usageOutput.printUsage(context.command);
}
