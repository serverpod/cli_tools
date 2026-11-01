import '../../config/config.dart'
    show
        ConfigOptionBase,
        OptionDefinition,
        FlagOption,
        ComparableValueOption,
        addOptionsToReceiver,
        OptionReceiver;
import 'command_usage.dart' show wrapTextAsLines;

class OptionsUsageGenerator {
  late final List<OptionOrSeparator> _optionItems;
  final int? lineLength;

  OptionsUsageGenerator(
    final Iterable<OptionDefinition> options, {
    this.lineLength,
    final bool addGroupSeparators = false,
  }) {
    final receiver = OptionItemReceiver();
    addOptionsToReceiver(
      options,
      receiver,
      addGroupSeparators: addGroupSeparators,
    );
    _optionItems = receiver._optionItems;
  }

  final Map<ConfigOptionBase, String> _optionTitles = {};
  final Map<ConfigOptionBase, String> _optionBodies = {};

  String generate() {
    final visibleOptions = _optionItems
        .where((final i) => i.isOption)
        .map((final i) => i.option)
        .where((final o) => !o.hide)
        .toList();

    _optionTitles.addEntries(
      visibleOptions.map((final o) => MapEntry(o, _generateOptionTitle(o))),
    );

    final maxTitleWidth = _optionTitles.values
        .map((final t) => t.length)
        .reduce((final a, final b) => a > b ? a : b);
    const gutter = 4;
    final indent = maxTitleWidth + gutter;

    _optionBodies.addEntries(
      visibleOptions.map(
        (final o) => MapEntry(o, _generateOptionBody(o, indent, lineLength)),
      ),
    );

    final buffer = StringBuffer();
    for (final optionItem in _optionItems) {
      if (optionItem.isOption) {
        final title = _optionTitles[optionItem.option];
        final body = _optionBodies[optionItem.option];
        if (title == null || body == null) continue;
        buffer.write(_writeCompactOption(title, body, indent));
      } else {
        buffer
          ..writeln()
          ..writeln(optionItem.separator);
      }
    }
    return buffer.toString();
  }

  static String _writeCompactOption(
    final String title,
    final String body,
    final int indent,
  ) {
    final buffer = StringBuffer()
      ..write(title.padRight(indent))
      ..write(body);
    return buffer.toString();
  }

  static String _generateOptionTitle(final ConfigOptionBase option) {
    final buffer = StringBuffer();
    if (option.argName != null) {
      if (option.argPos != null) {
        buffer.write('{${option.argPos}}, ');
      }
      if (option.argAbbrev != null) {
        buffer.write('-${option.argAbbrev}, ');
      }
      if (option is FlagOption &&
          option.negatable &&
          !option.hideNegatedUsage) {
        buffer.write('--[no-]${option.argName}');
      } else {
        buffer.write('--${option.argName}');
      }
      return buffer.toString();
    }

    if (option.envName != null) {
      buffer.write('${option.envName}');
      return buffer.toString();
    }

    final configKeys = option.configKeys ?? [];
    if (configKeys.isNotEmpty) {
      final title = configKeys.map((final k) => '{$k}').join(', ');
      buffer.write(title);
      return buffer.toString();
    }
    return '';
  }

  String _generateOptionBody(
    final ConfigOptionBase option,
    final int indent,
    final int? lineLength,
  ) {
    final buffer = LayoutStringBuffer(indent: indent, lineLength: lineLength)
      ..writeln(_generateDescription(option), firstLineIndentDelta: -indent)
      ..maybeWriteln(_generateEnvVarName(option))
      ..maybeWriteln(_generateConfigKeys(option))
      ..maybeWriteln(_generateDefault(option))
      ..maybeWriteln(_generateMandatory(option))
      ..maybeWriteln(_generateValueHelp(option))
      ..maybeWriteln(_generateRange(option))
      ..maybeWriteln(_generateAllowedValuesHelp(option));
    return buffer.toString();
  }

  static String _generateDescription(final ConfigOptionBase option) {
    return option.helpText ?? '';
  }

  static String? _generateEnvVarName(final ConfigOptionBase option) {
    return option.envName != null ? 'env "${option.envName}"' : null;
  }

  static String? _generateConfigKeys(final ConfigOptionBase option) {
    final configKeys = option.configKeys ?? [];
    if (configKeys.isEmpty) return null;
    return configKeys.map((final k) => 'key "$k"').join('\n');
  }

  static String? _generateDefault(final ConfigOptionBase option) {
    final def = option.defaultValueString();
    if (def == null) return null;
    return '(defaults to $def)';
  }

  static String? _generateMandatory(final ConfigOptionBase option) {
    return option.mandatory ? '(mandatory)' : null;
  }

  static String? _generateValueHelp(final ConfigOptionBase option) {
    final valueHelp = option.valueHelp ?? '';
    return valueHelp.isNotEmpty ? valueHelp : null;
  }

  static String? _generateRange(final ConfigOptionBase option) {
    if (option case final ComparableValueOption comparable) {
      String? minStr, maxStr;
      if (comparable.min case final Comparable min) {
        minStr = option.valueParser.format(min);
      }
      if (comparable.max case final Comparable max) {
        maxStr = option.valueParser.format(max);
      }
      if (minStr == null && maxStr == null) return null;
      return 'values: [${minStr ?? ''} - ${maxStr ?? ''}]';
    }
    return null;
  }

  static String? _generateAllowedValuesHelp(final ConfigOptionBase option) {
    final helpValues = (option.allowedValues ?? [])
        .map((final v) => option.valueParser.format(v))
        .toList();
    final allowedHelp = option.allowedHelp ?? {};

    if (helpValues.isEmpty) {
      if (allowedHelp.isEmpty) return null;
      helpValues.addAll(allowedHelp.keys);
    } else if (allowedHelp.isEmpty) {
      return 'values: [${helpValues.join(', ')}]';
    }

    final maxValueWidth = helpValues
        .map((final v) => v.length)
        .reduce((final a, final b) => a > b ? a : b);
    final helpValueLabels = helpValues
        .map((final v) => '[$v]'.padRight(maxValueWidth + 2))
        .toList();

    final output = [
      for (int i = 0; i < helpValueLabels.length; i++)
        '${helpValueLabels[i]}  ${allowedHelp[helpValues[i]] ?? ''}',
    ];
    return output.join('\n');
  }
}

class LayoutStringBuffer {
  final StringBuffer _buffer = StringBuffer();

  int indent;
  int? lineLength;

  LayoutStringBuffer({
    this.indent = 0,
    this.lineLength,
  });

  void write(
    final Object? obj, {
    final int? firstLineIndentDelta,
    final int? indentDelta,
    final int? lineLength,
  }) {
    _buffer.write(
      _layoutText(
        obj.toString(),
        firstLineIndentDelta,
        indentDelta,
        lineLength,
      ),
    );
  }

  void writeln(
    final Object? obj, {
    final int? firstLineIndentDelta,
    final int? indentDelta,
    final int? lineLength,
  }) {
    _buffer.writeln(
      _layoutText(
        obj.toString(),
        firstLineIndentDelta,
        indentDelta,
        lineLength,
      ),
    );
  }

  void maybeWriteln(
    final Object? obj, {
    final int? firstLineIndentDelta,
    final int? indentDelta,
    final int? lineLength,
  }) {
    if (obj case final Object o) {
      _buffer.writeln(
        _layoutText(
          o.toString(),
          firstLineIndentDelta,
          indentDelta,
          lineLength,
        ),
      );
    }
  }

  String _layoutText(
    final String text,
    final int? firstLineIndentDelta,
    final int? indentDelta,
    final int? lineLengthOverride,
  ) {
    final firstIndent = indent + (firstLineIndentDelta ?? 0);
    final hangingIndent = indent + (indentDelta ?? 0);

    final lineLength = lineLengthOverride ?? this.lineLength;
    final wrappedText = wrapTextAsLines(
      text,
      start: hangingIndent,
      length: lineLength,
    );
    return (' ' * firstIndent) + wrappedText.join('\n${' ' * hangingIndent}');
  }

  @override
  String toString() {
    return _buffer.toString();
  }
}

class OptionOrSeparator {
  final ConfigOptionBase? _option;
  final String? _separator;

  OptionOrSeparator.option(ConfigOptionBase this._option) : _separator = null;

  OptionOrSeparator.separator(String this._separator) : _option = null;

  bool get isOption => _option != null;

  ConfigOptionBase get option {
    if (_option == null) throw StateError('Option is null');
    return _option;
  }

  String get separator {
    if (_separator == null) throw StateError('Separator is null');
    return _separator;
  }
}

class OptionItemReceiver implements OptionReceiver {
  final List<OptionOrSeparator> _optionItems = [];

  OptionItemReceiver();

  @override
  void addOption(final OptionDefinition option) {
    _optionItems.add(OptionOrSeparator.option(option.option));
  }

  @override
  void addSeparator(final String separator) {
    _optionItems.add(OptionOrSeparator.separator(separator));
  }
}
