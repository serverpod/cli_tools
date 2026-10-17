import 'dart:async' show FutureOr;

import 'package:collection/collection.dart';

import '../config/config.dart'
    show OptionDefinition, CommandUsageDefinition, CommandAliasesDefinition;
import 'command.dart' show Command;
import 'command_run_context.dart' show RunCommandContext;
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
  final CommandUsageDefinition usage = const CommandUsageDefinition(
    description: 'Show help for a command.',
    hidden: true,
  );

  @override
  final CommandAliasesDefinition aliases = const CommandAliasesDefinition();

  final List<Command<OptionDefinition, T>> Function() _helpCommands;

  HelpCommand({
    required final List<Command<OptionDefinition, T>> Function() helpCommands,
  }) : _helpCommands = helpCommands;

  @override
  bool get runStandalone => true;

  @override
  bool get canRunAsLeafCommand => true;

  @override
  List<Command<OptionDefinition, T>> get subcommands => _helpCommands()
      .whereNot((final command) => command.usage.hidden)
      .map((final command) => _HelpSubcommand(subcommand: command))
      .toList();

  @override
  FutureOr<T?> run(final RunCommandContext runContext) {
    // If run is called, this is the last command on the command line -
    // show the help for the previous command.
    final parent = runContext.prev;
    if (parent == null) throw StateError('A parent command is expected');
    _printCommandUsage(parent);
    return null;
  }
}

/// Wrapper that represents each actual subcommand but produces its usage help
/// instead of running it. By representing each subcommand to the parser,
/// it will correctly validate the command line with a 'help' command.
class _HelpSubcommand<T> extends Command<OptionDefinition, T> {
  @override
  String get name => _subcommand.name;

  @override
  CommandUsageDefinition get usage => _subcommand.usage;

  @override
  CommandAliasesDefinition get aliases => _subcommand.aliases;

  @override
  List<OptionDefinition> get persistentOptions => _subcommand.persistentOptions;

  @override
  List<OptionDefinition> get options => _subcommand.options;

  @override
  List<Command<OptionDefinition, T>> get subcommands => _subcommand.subcommands;

  final Command<OptionDefinition, T> _subcommand;

  _HelpSubcommand({
    required final Command<OptionDefinition, T> subcommand,
  }) : _subcommand = subcommand;

  @override
  bool get runStandalone => true;

  @override
  FutureOr<T?> run(final RunCommandContext runContext) {
    _printCommandUsage(runContext);
    return null;
  }
}

void _printCommandUsage(final RunCommandContext runContext) {
  final rootCommand = runContext.root().command;
  if (rootCommand is! CommandRunner) {
    throw StateError(
      'Help command requires the root command to be a CommandRunner'
      " but it's a ${rootCommand.runtimeType}.",
    );
  }
  rootCommand.usageOutput.printUsage(runContext.command);
}
