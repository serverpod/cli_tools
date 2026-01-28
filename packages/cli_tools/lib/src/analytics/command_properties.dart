import 'package:args/args.dart';
import 'package:args/command_runner.dart';

Map<String, dynamic> buildCommandPropertiesForAnalytics({
  required final ArgResults topLevelResults,
  required final ArgParser argParser,
  required final Map<String, Command> commands,
}) {
  const maskedValue = 'xxx';
  final properties = <String, dynamic>{};

  // Collect explicitly-provided options/flags and mask any values.
  void addOptions(final ArgResults results) {
    for (final optionName in results.options) {
      if (!results.wasParsed(optionName)) {
        continue;
      }
      final value = results[optionName];
      if (value is bool) {
        properties['flag_$optionName'] = value;
      } else if (value != null) {
        properties['option_$optionName'] = value is List
            ? List.filled(value.length, maskedValue)
            : maskedValue;
      }
    }
  }

  for (ArgResults? current = topLevelResults;
      current != null;
      current = current.command) {
    addOptions(current);
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

  // Use a consistent placeholder for any sensitive tokens.
  void addMasked() {
    tokens.add(maskedValue);
  }

  String? optionNameForAbbreviation(
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

  // Normalizes option tokens and tracks whether a value is expected next.
  bool handleOption(
    final String name, {
    required final bool isNegated,
    final bool hasInlineValue = false,
  }) {
    final option = currentParser.options[name];
    if (option == null) {
      addMasked();
      return false;
    }
    if (option.isFlag) {
      tokens.add(isNegated ? '--no-$name' : '--$name');
      return true;
    }
    tokens.add('--$name');
    if (!hasInlineValue) {
      expectingValue = true;
    }
    return true;
  }

  for (final arg in arguments) {
    if (afterDoubleDash) {
      addMasked();
      continue;
    }

    if (expectingValue) {
      addMasked();
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
        if (handleOption(name, isNegated: false, hasInlineValue: true)) {
          addMasked();
        }
        continue;
      }

      if (withoutPrefix.startsWith('no-')) {
        final name = withoutPrefix.substring(3);
        handleOption(name, isNegated: true);
        continue;
      }

      handleOption(withoutPrefix, isNegated: false);
      continue;
    }

    if (arg.startsWith('-') && arg != '-') {
      // Short options; expand to their long form when possible.
      final withoutPrefix = arg.substring(1);
      final equalIndex = withoutPrefix.indexOf('=');
      if (equalIndex != -1) {
        final abbreviation = withoutPrefix.substring(0, equalIndex);
        final name = optionNameForAbbreviation(currentParser, abbreviation);
        if (name == null) {
          addMasked();
          continue;
        }
        if (handleOption(name, isNegated: false, hasInlineValue: true)) {
          addMasked();
        }
        continue;
      }

      if (withoutPrefix.length == 1) {
        final name = optionNameForAbbreviation(currentParser, withoutPrefix);
        if (name == null) {
          addMasked();
          continue;
        }
        handleOption(name, isNegated: false);
        continue;
      }

      for (var i = 0; i < withoutPrefix.length; i++) {
        final abbreviation = withoutPrefix[i];
        final name = optionNameForAbbreviation(currentParser, abbreviation);
        if (name == null) {
          addMasked();
          break;
        }
        final option = currentParser.options[name];
        if (option == null) {
          addMasked();
          break;
        }
        if (option.isFlag) {
          tokens.add('--$name');
          continue;
        }
        tokens.add('--$name');
        if (i < withoutPrefix.length - 1) {
          addMasked();
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

    addMasked();
  }

  return tokens.join(' ');
}
