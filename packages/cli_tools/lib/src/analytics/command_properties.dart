import 'package:args/args.dart';
import 'package:args/command_runner.dart';

Map<String, dynamic> buildCommandPropertiesForAnalytics({
  required final ArgResults topLevelResults,
  required final ArgParser argParser,
  required final Map<String, Command> commands,
}) {
  const maskedValue = 'xxx';
  final properties = <String, dynamic>{};

  for (ArgResults? current = topLevelResults;
      current != null;
      current = current.command) {
    _addOptions(
      results: current,
      properties: properties,
      maskedValue: maskedValue,
    );
  }

  // Reconstruct the command in user input order, masking values.
  properties['full_command'] = _buildFullCommandForAnalytics(
    arguments: topLevelResults.arguments,
    maskedValue: maskedValue,
    argParser: argParser,
    commands: commands,
  );

  return properties;
}

String _buildFullCommandForAnalytics({
  required final List<String> arguments,
  required final String maskedValue,
  required final ArgParser argParser,
  required final Map<String, Command> commands,
}) {
  final tokens = <String>[];
  var currentParser = argParser;
  var currentCommands = commands;
  var afterDoubleDash = false;
  var expectingValue = false;

  for (final arg in arguments) {
    if (afterDoubleDash) {
      _addMasked(tokens, maskedValue);
      continue;
    }

    if (expectingValue) {
      _addMasked(tokens, maskedValue);
      expectingValue = false;
      continue;
    }

    if (arg == '--') {
      afterDoubleDash = true;
      tokens.add('--');
      continue;
    }

    if (arg.startsWith('--')) {
      // Long options; normalize and mask any provided value.
      final withoutPrefix = arg.substring(2);
      final equalIndex = withoutPrefix.indexOf('=');
      if (equalIndex != -1) {
        final name = withoutPrefix.substring(0, equalIndex);
        if (_handleOption(
          name: name,
          currentParser: currentParser,
          tokens: tokens,
          maskedValue: maskedValue,
          isNegated: false,
          hasInlineValue: true,
          expectingValueSetter: (final value) => expectingValue = value,
        )) {
          _addMasked(tokens, maskedValue);
        }
        continue;
      }

      if (withoutPrefix.startsWith('no-')) {
        final name = withoutPrefix.substring(3);
        _handleOption(
          name: name,
          currentParser: currentParser,
          tokens: tokens,
          maskedValue: maskedValue,
          isNegated: true,
          expectingValueSetter: (final value) => expectingValue = value,
        );
        continue;
      }

      _handleOption(
        name: withoutPrefix,
        currentParser: currentParser,
        tokens: tokens,
        maskedValue: maskedValue,
        isNegated: false,
        expectingValueSetter: (final value) => expectingValue = value,
      );
      continue;
    }

    if (arg.startsWith('-') && arg != '-') {
      // Short options; expand to their long form when possible.
      final withoutPrefix = arg.substring(1);
      final equalIndex = withoutPrefix.indexOf('=');
      if (equalIndex != -1) {
        final abbreviation = withoutPrefix.substring(0, equalIndex);
        final name = _optionNameForAbbreviation(currentParser, abbreviation);
        if (name == null) {
          _addMasked(tokens, maskedValue);
          continue;
        }
        if (_handleOption(
          name: name,
          currentParser: currentParser,
          tokens: tokens,
          maskedValue: maskedValue,
          isNegated: false,
          hasInlineValue: true,
          expectingValueSetter: (final value) => expectingValue = value,
        )) {
          _addMasked(tokens, maskedValue);
        }
        continue;
      }

      if (withoutPrefix.length == 1) {
        final name = _optionNameForAbbreviation(currentParser, withoutPrefix);
        if (name == null) {
          _addMasked(tokens, maskedValue);
          continue;
        }
        _handleOption(
          name: name,
          currentParser: currentParser,
          tokens: tokens,
          maskedValue: maskedValue,
          isNegated: false,
          expectingValueSetter: (final value) => expectingValue = value,
        );
        continue;
      }

      for (var i = 0; i < withoutPrefix.length; i++) {
        final abbreviation = withoutPrefix[i];
        final name = _optionNameForAbbreviation(currentParser, abbreviation);
        if (name == null) {
          _addMasked(tokens, maskedValue);
          break;
        }
        final option = currentParser.options[name];
        if (option == null) {
          _addMasked(tokens, maskedValue);
          break;
        }
        if (option.isFlag) {
          tokens.add('--$name');
          continue;
        }
        tokens.add('--$name');
        if (i < withoutPrefix.length - 1) {
          _addMasked(tokens, maskedValue);
        } else {
          expectingValue = true;
        }
        break;
      }
      continue;
    }

    final command = currentCommands[arg];
    if (command != null) {
      tokens.add(arg);
      currentParser = command.argParser;
      currentCommands = command.subcommands;
      continue;
    }

    _addMasked(tokens, maskedValue);
  }

  return tokens.join(' ');
}

void _addOptions({
  required final ArgResults results,
  required final Map<String, dynamic> properties,
  required final String maskedValue,
}) {
  for (final optionName in results.options) {
    if (!results.wasParsed(optionName)) {
      continue;
    }
    final value = results[optionName];
    if (value is bool) {
      properties['flag_$optionName'] = value;
    } else if (value != null) {
      properties['option_$optionName'] =
          value is List ? List.filled(value.length, maskedValue) : maskedValue;
    }
  }
}

void _addMasked(final List<String> tokens, final String maskedValue) {
  tokens.add(maskedValue);
}

String? _optionNameForAbbreviation(
  final ArgParser parser,
  final String abbreviation,
) {
  final option = parser.findByAbbreviation(abbreviation);
  if (option == null) {
    return null;
  }
  for (final entry in parser.options.entries) {
    if (entry.value == option) {
      return entry.key;
    }
  }
  return null;
}

bool _handleOption({
  required final String name,
  required final ArgParser currentParser,
  required final List<String> tokens,
  required final String maskedValue,
  required final bool isNegated,
  required final void Function(bool) expectingValueSetter,
  final bool hasInlineValue = false,
}) {
  final option = currentParser.options[name];
  if (option == null) {
    _addMasked(tokens, maskedValue);
    return false;
  }
  if (option.isFlag) {
    tokens.add(isNegated ? '--no-$name' : '--$name');
    return true;
  }
  tokens.add('--$name');
  if (!hasInlineValue) {
    expectingValueSetter(true);
  }
  return true;
}
