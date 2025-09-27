import 'dart:io' show IOSink;

import 'package:args/command_runner.dart' show Command;
import 'package:config/config.dart';

import '../better_command.dart';
import '../better_command_runner.dart';

/// Interface for generating a usage representation for a command.
abstract interface class UsageRepresentationGenerator {
  void generate(
    final IOSink out,
    final CommandUsage usage,
  );
}

class CommandUsage<O extends OptionDefinition> {
  final List<String> commandSequence;
  final List<CommandUsage> subcommands;

  /// Persistent options - the options of the current command that continue to
  /// be available for all subcommands.
  /// (In Dart, this usually only applies to global options.)
  final List<O> persistentOptions;

  /// Regular options - the options of the current command that are not
  /// persistent.
  final List<O> options;

  CommandUsage({
    required this.commandSequence,
    required this.subcommands,
    required this.persistentOptions,
    required this.options,
  });

  String get command => commandSequence.last;
}

abstract class UsageRepresentation {
  /// Compiles a usage representation tree for all subcommands and options
  /// for a command runner.
  static CommandUsage compile(
    final BetterCommandRunner runner, {
    final String? execNameOverride,
  }) {
    return _generateForCommand(
      [execNameOverride ?? runner.executableName],
      runner.commands.values,
      _filterOptions(runner.globalOptions),
      const [],
    );
  }

  static CommandUsage _generateForCommand(
    final List<String> commandSequence,
    final Iterable<Command> subcommands,
    final List<OptionDefinition> persistentOptions,
    final List<OptionDefinition> options,
  ) {
    final validOptions = _filterOptions(options);
    final validSubcommands =
        subcommands.whereType<BetterCommand>().where((final c) => !c.hidden);

    return CommandUsage(
      commandSequence: commandSequence,
      persistentOptions: persistentOptions,
      options: validOptions,
      subcommands: validSubcommands
          .map((final subcommand) => _generateForCommand(
                [...commandSequence, subcommand.name],
                subcommand.subcommands.values,
                const [],
                subcommand.options,
              ))
          .toList(),
    );
  }

  static List<OptionDefinition> _filterOptions(
    final List<OptionDefinition> options,
  ) {
    return options
        .where((final o) => !o.option.hide)
        .where((final o) =>
            o.option.argName != null ||
            o.option.argAbbrev != null ||
            o.option.argPos != null)
        .toList();
  }
}
