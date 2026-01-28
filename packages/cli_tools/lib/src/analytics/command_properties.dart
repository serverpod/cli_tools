import 'package:args/args.dart';
import 'package:args/command_runner.dart';

Map<String, dynamic> buildCommandPropertiesForAnalytics({
  required final ArgResults topLevelResults,
  required final ArgParser argParser,
  required final Map<String, Command> commands,
}) {
  return _CommandPropertiesBuilder(
    topLevelResults: topLevelResults,
    argParser: argParser,
    commands: commands,
  ).build();
}

class _CommandPropertiesBuilder {
  _CommandPropertiesBuilder({
    required this.topLevelResults,
    required this.argParser,
    required this.commands,
  });

  static const _maskedValue = 'xxx';

  final ArgResults topLevelResults;
  final ArgParser argParser;
  final Map<String, Command> commands;
  final Map<String, dynamic> _properties = <String, dynamic>{};

  late List<String> _tokens;
  late ArgParser _currentParser;
  late Map<String, Command> _currentCommands;
  var _afterDoubleDash = false;
  var _expectingValue = false;

  Map<String, dynamic> build() {
    _collectOptions();
    _properties['full_command'] = _buildFullCommand();
    return _properties;
  }

  void _collectOptions() {
    for (ArgResults? current = topLevelResults;
        current != null;
        current = current.command) {
      _addOptions(current);
    }
  }

  void _addOptions(final ArgResults results) {
    for (final optionName in results.options) {
      if (!results.wasParsed(optionName)) {
        continue;
      }
      final value = results[optionName];
      if (value is bool) {
        _properties['flag_$optionName'] = value;
      } else if (value != null) {
        _properties['option_$optionName'] = value is List
            ? List.filled(value.length, _maskedValue)
            : _maskedValue;
      }
    }
  }

  String _buildFullCommand() {
    _resetCommandState();

    for (final arg in topLevelResults.arguments) {
      if (_afterDoubleDash) {
        _addMasked();
        continue;
      }

      if (_expectingValue) {
        _addMasked();
        _expectingValue = false;
        continue;
      }

      if (arg == '--') {
        _afterDoubleDash = true;
        _tokens.add('--');
        continue;
      }

      if (arg.startsWith('--')) {
        _handleLongOption(arg);
        continue;
      }

      if (arg.startsWith('-') && arg != '-') {
        _handleShortOption(arg);
        continue;
      }

      final command = _currentCommands[arg];
      if (command != null) {
        _tokens.add(arg);
        _currentParser = command.argParser;
        _currentCommands = command.subcommands;
        continue;
      }

      _addMasked();
    }

    return _tokens.join(' ');
  }

  void _resetCommandState() {
    _tokens = <String>[];
    _currentParser = argParser;
    _currentCommands = commands;
    _afterDoubleDash = false;
    _expectingValue = false;
  }

  void _handleLongOption(final String arg) {
    // Long options; normalize and mask any provided value.
    final withoutPrefix = arg.substring(2);
    final equalIndex = withoutPrefix.indexOf('=');
    if (equalIndex != -1) {
      final name = withoutPrefix.substring(0, equalIndex);
      final handled = _handleOption(
        name: name,
        isNegated: false,
        hasInlineValue: true,
      );
      if (handled) {
        _addMasked();
      }
      return;
    }

    if (withoutPrefix.startsWith('no-')) {
      final name = withoutPrefix.substring(3);
      _handleOption(name: name, isNegated: true);
      return;
    }

    _handleOption(name: withoutPrefix, isNegated: false);
  }

  void _handleShortOption(final String arg) {
    // Short options; expand to their long form when possible.
    final withoutPrefix = arg.substring(1);
    final equalIndex = withoutPrefix.indexOf('=');
    if (equalIndex != -1) {
      final abbreviation = withoutPrefix.substring(0, equalIndex);
      final name = _optionNameForAbbreviation(abbreviation);
      if (name == null) {
        _addMasked();
        return;
      }
      final handled = _handleOption(
        name: name,
        isNegated: false,
        hasInlineValue: true,
      );
      if (handled) {
        _addMasked();
      }
      return;
    }

    if (withoutPrefix.length == 1) {
      final name = _optionNameForAbbreviation(withoutPrefix);
      if (name == null) {
        _addMasked();
        return;
      }
      _handleOption(name: name, isNegated: false);
      return;
    }

    for (var i = 0; i < withoutPrefix.length; i++) {
      final abbreviation = withoutPrefix[i];
      final name = _optionNameForAbbreviation(abbreviation);
      if (name == null) {
        _addMasked();
        break;
      }
      final option = _currentParser.options[name];
      if (option == null) {
        _addMasked();
        break;
      }
      if (option.isFlag) {
        _tokens.add('--$name');
        continue;
      }
      _tokens.add('--$name');
      if (i < withoutPrefix.length - 1) {
        _addMasked();
      } else {
        _expectingValue = true;
      }
      break;
    }
  }

  void _addMasked() {
    _tokens.add(_maskedValue);
  }

  String? _optionNameForAbbreviation(final String abbreviation) {
    final option = _currentParser.findByAbbreviation(abbreviation);
    if (option == null) {
      return null;
    }
    for (final entry in _currentParser.options.entries) {
      if (entry.value == option) {
        return entry.key;
      }
    }
    return null;
  }

  bool _handleOption({
    required final String name,
    required final bool isNegated,
    final bool hasInlineValue = false,
  }) {
    final option = _currentParser.options[name];
    if (option == null) {
      _addMasked();
      _expectingValue = false;
      return false;
    }
    if (option.isFlag) {
      _tokens.add(isNegated ? '--no-$name' : '--$name');
      _expectingValue = false;
      return true;
    }
    _tokens.add('--$name');
    _expectingValue = !hasInlineValue;
    return true;
  }
}
