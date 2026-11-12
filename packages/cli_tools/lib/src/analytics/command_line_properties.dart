import 'package:config/command.dart';
import 'package:config/config.dart';

const _maskedValue = 'xxx';

/// Builds analytics properties for the command line represented by [context]
/// from the new Command framework.
///
/// The result contains `flag_<name>` for flags set on the command line,
/// `option_<name>` for other command-line options with values replaced by
/// `xxx`, and `full_command`, a sanitized command line. Only values set on
/// the command line are included.
///
/// [context] may be any command in the chain; the description runs from the
/// root command through the leaf. The executable name is not included.
/// Subcommands and options are written with their canonical names, and options
/// follow definition order on the command that owns them. A `--` separator is
/// restored before a positional that starts with `-`, which is only possible
/// for arguments passed through after `--`.
Map<String, dynamic> buildCommandLinePropertiesForAnalytics<
  O extends OptionDefinition,
  T
>(final CommandContext<O, T> context) {
  return _CommandContextPropertiesBuilder<T>(context.root()).build();
}

class _CommandContextPropertiesBuilder<T> {
  _CommandContextPropertiesBuilder(this._root);

  final CommandContext<OptionDefinition, T> _root;
  final Map<String, dynamic> _properties = <String, dynamic>{};
  final List<String> _tokens = <String>[];
  var _doubleDashEmitted = false;

  Map<String, dynamic> build() {
    _visit(_root);
    _properties['full_command'] = _tokens.join(' ');
    return _properties;
  }

  void _visit(final CommandContext<OptionDefinition, T> context) {
    if (context.prev != null) {
      _tokens.add(context.command.name);
    }
    _addConfiguration(context.config);
    _addConfiguration(context.builtinConfig);
    for (final arg in context.config.remainingPosArgs) {
      _addMaskedPositional(arg);
    }

    final next = context.next;
    if (next != null) _visit(next);
  }

  void _addConfiguration<P extends OptionDefinition>(
    final Configuration<P> config,
  ) {
    for (final option in config.optionsWhereSource(
      (final source) => source == ValueSourceType.arg,
    )) {
      final Object? value;
      try {
        value = config.optionalValue<dynamic>(option);
      } on InvalidParseStateError {
        continue;
      }
      _addOption(option, value);
    }
  }

  void _addOption(final OptionDefinition option, final Object? value) {
    if (value is bool || option.option is FlagOption) {
      _addFlag(option, value);
      return;
    }
    if (value == null) return;
    _addValuedOption(option, value);
  }

  void _addFlag(final OptionDefinition option, final Object? value) {
    if (value is! bool) return;
    final name = option.option.argName;
    if (name == null) return;

    _properties['flag_$name'] = value;
    final definition = option.option;
    final negated = !value && definition is FlagOption && definition.negatable;
    _tokens.add(negated ? '--no-$name' : '--$name');
  }

  void _addValuedOption(final OptionDefinition option, final Object value) {
    final name = option.option.argName;
    final count = value is List ? value.length : 1;
    if (name != null) {
      _properties['option_$name'] = value is List
          ? List<String>.filled(count, _maskedValue)
          : _maskedValue;
    }
    if (count == 0) return;

    if (name == null) {
      if (value is List) {
        for (final element in value) {
          _addMaskedPositional(element is String ? element : null);
        }
      } else {
        _addMaskedPositional(value is String ? value : null);
      }
      return;
    }

    for (var i = 0; i < count; i++) {
      _tokens.add('--$name');
      _tokens.add(_maskedValue);
    }
  }

  /// Masks one positional word.
  ///
  /// A word shaped like an option was passed through after `--`, so the
  /// separator is written once before the first such word.
  void _addMaskedPositional(final String? raw) {
    if (!_doubleDashEmitted &&
        raw != null &&
        raw.startsWith('-') &&
        raw.length > 1) {
      _tokens.add('--');
      _doubleDashEmitted = true;
    }
    _tokens.add(_maskedValue);
  }
}
