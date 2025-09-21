import 'dart:io' show IOSink;

import 'package:config/config.dart';

import 'usage_representation.dart';

/// Generates usage representation for a command in the YAML format
/// of the `completely` tool.
/// https://github.com/bashly-framework/completely
class CompletelyYamlGenerator implements UsageRepresentationGenerator {
  @override
  void generate(
    final IOSink out,
    final CommandUsage usage,
  ) {
    _innerGenerate(out, usage, const []);
  }

  void _innerGenerate(
    final IOSink out,
    final CommandUsage usage,
    final List<OptionDefinition> inheritedOptions,
  ) {
    if (usage.subcommands.isEmpty &&
        usage.persistentOptions.isEmpty &&
        usage.options.isEmpty &&
        inheritedOptions.isEmpty) {
      return;
    }

    out.writeln('${usage.commandSequence.join(' ')}:');

    for (final subcommand in usage.subcommands) {
      out.writeln('  - ${subcommand.command}');
    }

    _generateCompletelyForOptions(out, usage, inheritedOptions);
    out.writeln();

    final propagatedOptions = [...inheritedOptions, ...usage.persistentOptions];
    for (final subcommand in usage.subcommands) {
      _innerGenerate(out, subcommand, propagatedOptions);
    }
  }

  static void _generateCompletelyForOptions(
    final IOSink out,
    final CommandUsage usage,
    final List<OptionDefinition> inheritedOptions,
  ) {
    final allOptions = [
      ...inheritedOptions,
      ...usage.persistentOptions,
      ...usage.options
    ];

    // options
    for (final option in allOptions) {
      if (option.option.argName != null) {
        out.writeln('  - --${option.option.argName}');

        if (option.option case final FlagOption flagOption) {
          if (flagOption.negatable && !flagOption.hideNegatedUsage) {
            out.writeln('  - --no-${flagOption.argName}');
          }
        }
      }

      if (option.option.argAbbrev != null) {
        out.writeln('  - -${option.option.argAbbrev}');
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
    for (final option in allOptions) {
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
        '  --$argName',
      );
    }
    if (option.argAbbrev case final String argAbbrev) {
      _generateCompletelyForArgNameOption(
        out,
        commandSequence,
        option,
        '  -$argAbbrev',
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
      return allowedValues.map(option.valueParser.format).toList();
    }

    switch (option.option) {
      case EnumOption():
        final enumParser = option.option.valueParser as EnumParser;
        return enumParser.enumValues.map(enumParser.format).toList();
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
      out.writeln('  - $value');
    }
  }
}
