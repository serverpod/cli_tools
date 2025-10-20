import 'dart:io' show IOSink;

import 'package:config/config.dart';

import 'usage_representation.dart';

/// Generates usage representation for a command in the YAML format
/// of the `carapace` tool.
/// https://github.com/carapace-sh/carapace
class CarapaceYamlGenerator implements UsageRepresentationGenerator {
  @override
  void generate(
    final IOSink out,
    final CommandUsage usage,
  ) {
    out.writeln(
        r'# yaml-language-server: $schema=https://carapace.sh/schemas/command.json');

    _generateForCommand(out, usage, 0);
  }

  void _generateForCommand(
    final IOSink out,
    final CommandUsage usage,
    int indentLevel,
  ) {
    if (indentLevel == 0) {
      _writeWithIndent(out, 'name: ${usage.commandSequence.last}', indentLevel);
    } else {
      _writeWithIndent(
          out, '- name: ${usage.commandSequence.last}', indentLevel);
      indentLevel += 1;
    }

    if (usage.persistentOptions.isNotEmpty) {
      _writeWithIndent(out, 'persistentFlags:', indentLevel);
      _declareOptions(out, usage.persistentOptions, indentLevel + 1);
    }

    if (usage.options.isNotEmpty) {
      _writeWithIndent(out, 'flags:', indentLevel);
      _declareOptions(out, usage.options, indentLevel + 1);
    }

    final allOptions = [...usage.persistentOptions, ...usage.options];

    final exclusiveGroups = _generateExclusiveOptionGroups(allOptions);
    if (exclusiveGroups.isNotEmpty) {
      _writeWithIndent(out, 'exclusiveFlags:', indentLevel);
      for (final group in exclusiveGroups) {
        _writeWithIndent(out, '- [${group.join(', ')}]', indentLevel + 1);
      }
    }

    final specs = _generateOptionCompletionSpecs(allOptions);
    if (specs.isNotEmpty) {
      _writeWithIndent(out, 'completion:', indentLevel);
      _writeWithIndent(out, 'flag:', indentLevel + 1);
      for (final spec in specs) {
        _writeWithIndent(out, spec, indentLevel + 2);
      }
    }

    out.writeln();

    if (usage.subcommands.isNotEmpty) {
      _writeWithIndent(out, 'commands:', indentLevel);
      for (final subcommand in usage.subcommands) {
        _generateForCommand(out, subcommand, indentLevel + 1);
      }
    }
  }

  static void _writeWithIndent(
    final IOSink out,
    final String text,
    final int indentLevel,
  ) {
    out.writeln('${_getIndent(indentLevel)}$text');
  }

  static String _getIndent(final int indentLevel) => '  ' * indentLevel;

  static void _declareOptions(
    final IOSink out,
    final List<OptionDefinition> options,
    final int indentLevel,
  ) {
    // options
    for (final option in options) {
      _declareOption(out, option.option, indentLevel);
    }
  }

  static void _declareOption(
    final IOSink out,
    final ConfigOptionBase option,
    final int indentLevel,
  ) {
    final names = [
      if (option.argAbbrev != null) '-${option.argAbbrev}',
      if (option.argName != null) '--${option.argName}',
    ];

    String attributes = '';
    if (option is! FlagOption) {
      attributes += '=';
    }
    if (option is MultiOption) {
      attributes += '*';
    }
    if (option.mandatory && option is! FlagOption) {
      attributes += '!';
    }

    final optionHelp = _formatYamlStringValue(option.helpText ?? '');
    _writeWithIndent(
      out,
      '${names.join(', ')}$attributes: $optionHelp',
      indentLevel,
    );

    if (option case final FlagOption flagOption) {
      if (flagOption.negatable && !flagOption.hideNegatedUsage) {
        _writeWithIndent(
          out,
          '--no-${option.argName}$attributes: $optionHelp',
          indentLevel,
        );
      }
    }
  }

  static List<List<String>> _generateExclusiveOptionGroups(
    final List<OptionDefinition> options,
  ) {
    final groups = <List<String>>[];
    for (final option in options) {
      if (option.option case final FlagOption flagOption) {
        final argName = flagOption.argName;
        if (argName != null &&
            flagOption.negatable &&
            !flagOption.hideNegatedUsage) {
          groups.add([argName, 'no-$argName']);
        }
      }
    }
    return groups;
  }

  static List<String> _generateOptionCompletionSpecs(
    final List<OptionDefinition> options,
  ) {
    final specs = <String>[];
    for (final option in options) {
      final name = option.option.argName ?? option.option.argAbbrev;
      if (name == null) {
        continue;
      }

      final values = _getOptionValues(option.option);
      if (values.isNotEmpty) {
        final valueSpec = values.map((final v) => '"$v"').join(', ');
        specs.add('$name: [$valueSpec]');
      }
    }
    return specs;
  }

  static List<String> _getOptionValues(
    final ConfigOptionBase option,
  ) {
    if (option case final MultiOption multiOption) {
      if (multiOption.allowedElementValues case final List allowedValues) {
        return allowedValues
            .map<String>(multiOption.multiParser.elementParser.format)
            .toList();
      }
    } else if (option.allowedValues case final List allowedValues) {
      return allowedValues.map(option.valueParser.format).toList();
    }

    switch (option.option) {
      case EnumOption():
        final enumParser = option.option.valueParser as EnumParser;
        return enumParser.enumValues.map(enumParser.format).toList();
      case FileOption():
        return [r'$files'];
      case DirOption():
        return [r'$directories'];
      default:
        return [];
    }
  }

  static String _formatYamlStringValue(final String value) {
    final str = value
        .replaceAll(r'\', r'\\')
        .replaceAll(r'"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\t', r'\t')
        .replaceAll('\r', r'\r');
    return '"$str"';
  }
}
