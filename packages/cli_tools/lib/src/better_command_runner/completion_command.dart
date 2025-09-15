import 'dart:io' show IOSink, stdout;

import 'package:args/command_runner.dart' show Command;
import 'package:config/config.dart';

import 'better_command.dart';
import 'better_command_runner.dart';

enum CompletionTarget {
  completely,
}

enum CompletionOption<V extends Object> implements OptionDefinition<V> {
  target(EnumOption(
    enumParser: EnumParser(CompletionTarget.values),
    argName: 'target',
    argAbbrev: 't',
    defaultsTo: CompletionTarget.completely,
  )),
  execName(StringOption(
    argName: 'exec-name',
    argAbbrev: 'e',
    helpText: 'Override the name of the executable',
  )),
  file(FileOption(
    argName: 'file',
    argAbbrev: 'f',
    helpText: 'Write the specification to a file instead of stdout',
  ));

  const CompletionOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

class CompletionCommand<T> extends BetterCommand<CompletionOption, T> {
  CompletionCommand() : super(options: CompletionOption.values);

  @override
  String get name => 'completion';

  @override
  String get description => 'Generate a command line completion specification';

  @override
  Null runWithConfig(final Configuration<CompletionOption> commandConfig) {
    final target = commandConfig.value(CompletionOption.target);
    final execName = commandConfig.optionalValue(CompletionOption.execName);
    final file = commandConfig.optionalValue(CompletionOption.file);

    final betterRunner = runner;
    if (betterRunner == null) {
      throw Exception('BetterCommandRunner not set in the completion command');
    }

    final usage = UsageRepresentation.compile(
      betterRunner,
      execNameOverride: execName,
    );

    final IOSink out = file?.openWrite() ?? stdout;

    switch (target) {
      case CompletionTarget.completely:
        CompletelyYamlGenerator().generate(out, usage);
        break;
    }
  }
}

class CommandUsage<O extends OptionDefinition> {
  final List<String> commandSequence;
  final List<O> options;
  final List<CommandUsage> subcommands;

  CommandUsage({
    required this.commandSequence,
    required this.options,
    required this.subcommands,
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
      _filterOptions(runner.globalOptions),
      runner.commands.values,
      const [],
    );
  }

  static CommandUsage _generateForCommand(
    final List<String> commandSequence,
    final List<OptionDefinition> globalOptions,
    final Iterable<Command> subcommands,
    final List<OptionDefinition> options,
  ) {
    final validOptions = [...globalOptions, ..._filterOptions(options)];
    final validSubcommands =
        subcommands.whereType<BetterCommand>().where((final c) => !c.hidden);

    return CommandUsage(
      commandSequence: commandSequence,
      options: validOptions,
      subcommands: validSubcommands
          .map((final subcommand) => _generateForCommand(
                [...commandSequence, subcommand.name],
                globalOptions,
                subcommand.subcommands.values,
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
        .where((final o) => o.option.argName != null || o.option.argPos != null)
        .toList();
  }
}

/// Interface for generating a usage representation for a command.
abstract interface class UsageRepresentationGenerator {
  void generate(
    final IOSink out,
    final CommandUsage usage,
  );
}

/// Generates usage representation for a command in the YAML format
/// of the `completely` tool.
/// https://github.com/bashly-framework/completely
class CompletelyYamlGenerator implements UsageRepresentationGenerator {
  @override
  void generate(
    final IOSink out,
    final CommandUsage usage,
  ) {
    if (usage.subcommands.isEmpty && usage.options.isEmpty) {
      return;
    }

    out.writeln('${usage.commandSequence.join(' ')}:');

    for (final subcommand in usage.subcommands) {
      out.writeln('- ${subcommand.command}');
    }

    _generateCompletelyForOptions(out, usage);
    out.writeln();

    for (final subcommand in usage.subcommands) {
      generate(out, subcommand);
    }
  }

  static void _generateCompletelyForOptions(
    final IOSink out,
    final CommandUsage usage,
  ) {
    // options
    for (final option in usage.options) {
      if (option.option.argName != null) {
        out.writeln('- --${option.option.argName}');

        if (option.option case final FlagOption flagOption) {
          if (flagOption.negatable && !flagOption.hideNegatedUsage) {
            out.writeln('- --no-${flagOption.argName}');
          }
        }
      }

      if (option.option.argAbbrev != null) {
        out.writeln('- -${option.option.argAbbrev}');
      }

      if (option.option.argPos == 0) {
        final values = _getOptionValues(option.option);
        if (values.isNotEmpty) {
          _generateCompletelyForOptionValues(out, values);
        }
      }
      // can't currently complete for positional options after the first one
    }

    // value completions for each option
    for (final option in usage.options) {
      _generateCompletelyForOption(out, usage.commandSequence, option.option);
    }
  }

  static void _generateCompletelyForOption(
    final IOSink out,
    final List<String> commandSequence,
    final ConfigOptionBase option,
  ) {
    if (option is FlagOption) {
      return;
    }

    if (option.argName case final String argName) {
      _generateCompletelyForArgNameOption(
        out,
        commandSequence,
        option,
        '--$argName',
      );
    }
    if (option.argAbbrev case final String argAbbrev) {
      _generateCompletelyForArgNameOption(
        out,
        commandSequence,
        option,
        '-$argAbbrev',
      );
    }
  }

  static void _generateCompletelyForArgNameOption(
    final IOSink out,
    final List<String> commandSequence,
    final ConfigOptionBase option,
    final String argName,
  ) {
    final values = _getOptionValues(option);
    if (values.isNotEmpty) {
      out.writeln('${commandSequence.join(' ')}*$argName:');
      _generateCompletelyForOptionValues(out, values);
    }
  }

  static List<String> _getOptionValues(
    final ConfigOptionBase option,
  ) {
    if (option.allowedValues case final List allowedValues) {
      return allowedValues.map((final v) => '$v').toList();
    }

    switch (option.option) {
      case EnumOption():
        final enumParser = option.option.valueParser as EnumParser;
        return enumParser.enumValues.map((final e) => e.name).toList();
      case FileOption():
        return ['<file>'];
      case DirOption():
        return ['<directory>'];
      default:
        return [];
    }
  }

  static void _generateCompletelyForOptionValues(
    final IOSink out,
    final Iterable values,
  ) {
    for (final value in values) {
      out.writeln('- $value');
    }
  }
}
