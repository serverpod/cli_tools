import 'dart:io' show IOSink;

import 'package:config/config.dart';

import '../command.dart';
import '../command_runner.dart';

/// Interface for generating a usage representation for a command.
abstract interface class UsageRepresentationGenerator {
  void generate(
    IOSink out,
    CommandUsage usage,
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
    NewCommandRunner runner, {
    String? execNameOverride,
  }) {
    return _generateForCommand(
      [execNameOverride ?? runner.executableName],
      runner.commands.values,
      _filterOptions(runner.globalOptions),
      const [],
    );
  }

  static CommandUsage _generateForCommand(
    List<String> commandSequence,
    Iterable<NewCommand> subcommands,
    List<OptionDefinition> persistentOptions,
    List<OptionDefinition> options,
  ) {
    final validOptions = _filterOptions(options);
    final validSubcommands = subcommands.whereType<NewCommand>().where(
      (c) => !c.hidden,
    );

    return CommandUsage(
      commandSequence: commandSequence,
      persistentOptions: persistentOptions,
      options: validOptions,
      subcommands: validSubcommands
          .map(
            (subcommand) => _generateForCommand(
              [...commandSequence, subcommand.name],
              subcommand.subcommands.values,
              const [],
              subcommand.options,
            ),
          )
          .toList(),
    );
  }

  static List<OptionDefinition> _filterOptions(
    List<OptionDefinition> options,
  ) {
    return options
        .where((o) => !o.option.hide)
        .where(
          (o) =>
              o.option.argName != null ||
              o.option.argAbbrev != null ||
              o.option.argPos != null,
        )
        .toList();
  }
}
