// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math' as math;

import '../../../config.dart';
import 'command_usage.dart' show wrapTextAsLines;

/// Generates a string of usage (i.e. help) text for a list of options.
///
/// Internally, it works like a tabular printer. The output is divided into
/// three horizontal columns, like so:
///
///     -h, --help  Prints the usage information
///     |  |        |                                 |
///
/// It builds the usage text up one column at a time and handles padding with
/// spaces and wrapping to the next line to keep the cells correctly lined up.
///
/// [lineLength] specifies the horizontal character position at which the help
/// text is wrapped. Help that extends past this column will be wrapped at the
/// nearest whitespace (or truncated if there is no available whitespace). If
/// `null` there will not be any wrapping.
String generateOptionsUsage(
  final List optionsAndSeparators, {
  final int? lineLength,
}) => _Usage(optionsAndSeparators, lineLength).generate();

class _Usage {
  /// Abbreviation, long name, help.
  static const _columnCount = 3;

  /// A list of the [OptionDefinition]s intermingled with [String] separators.
  final List _optionsAndSeparators;

  /// The working buffer for the generated usage text.
  final _buffer = StringBuffer();

  /// The column that the "cursor" is currently on.
  ///
  /// If the next call to [write()] is not for this column, it will correctly
  /// handle advancing to the next column (and possibly the next row).
  int _currentColumn = 0;

  /// The width in characters of each column.
  late final _columnWidths = _calculateColumnWidths();

  /// How many newlines need to be rendered before the next bit of text can be
  /// written.
  ///
  /// We do this lazily so that the last bit of usage doesn't have dangling
  /// newlines. We only write newlines right *before* we write some real
  /// content.
  int _newlinesNeeded = 0;

  /// The horizontal character position at which help text is wrapped.
  ///
  /// Help that extends past this column will be wrapped at the nearest
  /// whitespace (or truncated if there is no available whitespace).
  final int? lineLength;

  _Usage(this._optionsAndSeparators, this.lineLength);

  /// Generates a string displaying usage information for the defined options.
  /// This is basically the help text shown on the command line.
  String generate() {
    for (final optionOrSeparator in _optionsAndSeparators) {
      if (optionOrSeparator is String) {
        _writeSeparator(optionOrSeparator);
        continue;
      }
      final option = optionOrSeparator as OptionDefinition;
      if (option.option.hide) continue;
      _writeOption(option.option);
    }

    return _buffer.toString();
  }

  void _writeSeparator(final String separator) {
    // Ensure that there's always a blank line before a separator.
    if (_buffer.isNotEmpty) _buffer.write('\n\n');
    _buffer.write(separator);
    _newlinesNeeded = 1;
  }

  void _writeOption(final ConfigOptionBase option) {
    _write(0, _abbreviation(option));
    _write(1, '${_longOption(option)}${_mandatoryOption(option)}');

    if (option.helpText case final help?) _write(2, help);

    if (option.allowedHelp case final allowedHelp?) {
      _newline();
      for (final MapEntry(key: name, value: content) in allowedHelp.entries) {
        _write(1, _allowedTitle(option, name));
        _write(2, content);
      }
      _newline();
    } else if (option.allowedValues != null) {
      _write(2, _buildAllowedList(option));
    } else if (option case final FlagOption flag) {
      if (flag.defaultValue() == true) {
        _write(2, '(defaults to on)');
      }
    } else if (option case final MultiOption multi) {
      if (multi.defaultValue() != null && multi.defaultValue()!.isNotEmpty) {
        final defaults = multi
            .defaultValue()!
            .map((final value) => '"$value"')
            .join(', ');
        _write(2, '(defaults to $defaults)');
      }
    } else if (option.defaultValue() != null) {
      _write(2, '(defaults to "${option.defaultValue()}")');
    }
  }

  String _abbreviation(final ConfigOptionBase option) =>
      option.argAbbrev == null ? '' : '-${option.argAbbrev}, ';

  String _longOption(final ConfigOptionBase option) {
    final argName = option.argName;
    if (argName == null) return option.toString();

    String result;
    if (option is FlagOption && option.negatable && !option.hideNegatedUsage) {
      result = '--[no-]$argName';
    } else {
      result = '--$argName';
    }

    if (option.valueHelp != null) result += '=<${option.valueHelp}>';

    return result;
  }

  String _mandatoryOption(final ConfigOptionBase option) {
    return option.mandatory ? ' (mandatory)' : '';
  }

  String _allowedTitle(final ConfigOptionBase option, final String allowed) {
    final isDefault = option.defaultValue() is List
        ? (option.defaultValue() as List).contains(allowed)
        : option.defaultValue() == allowed;
    return '      [$allowed]${isDefault ? ' (default)' : ''}';
  }

  List<int> _calculateColumnWidths() {
    var abbr = 0;
    var title = 0;
    for (final opt in _optionsAndSeparators) {
      if (opt is! OptionDefinition) continue;
      final option = opt.option;
      if (option.hide) continue;

      // Make room in the first column if there are abbreviations.
      abbr = math.max(abbr, _abbreviation(option).length);

      // Make room for the option.
      title = math.max(
        title,
        _longOption(option).length + _mandatoryOption(option).length,
      );

      // Make room for the allowed help.
      if (option.allowedHelp != null) {
        for (final allowed in option.allowedHelp!.keys) {
          title = math.max(title, _allowedTitle(option, allowed).length);
        }
      }
    }

    // Leave a gutter between the columns.
    title += 4;
    return [abbr, title];
  }

  void _newline() {
    _newlinesNeeded++;
    _currentColumn = 0;
  }

  void _write(final int column, final String text) {
    var lines = text.split('\n');
    // If we are writing the last column, word wrap it to fit.
    if (column == _columnWidths.length && lineLength != null) {
      final start = _columnWidths
          .take(column)
          .reduce((final start, final width) => start + width);
      lines = [
        for (final line in lines)
          ...wrapTextAsLines(line, start: start, length: lineLength),
      ];
    }

    // Strip leading and trailing empty lines.
    while (lines.isNotEmpty && lines.first.trim() == '') {
      lines.removeAt(0);
    }
    while (lines.isNotEmpty && lines.last.trim() == '') {
      lines.removeLast();
    }

    for (final line in lines) {
      _writeLine(column, line);
    }
  }

  void _writeLine(final int column, final String text) {
    // Write any pending newlines.
    while (_newlinesNeeded > 0) {
      _buffer.write('\n');
      _newlinesNeeded--;
    }

    // Advance until we are at the right column (which may mean wrapping around
    // to the next line.
    while (_currentColumn != column) {
      if (_currentColumn < _columnCount - 1) {
        _buffer.write(' ' * _columnWidths[_currentColumn]);
      } else {
        _buffer.write('\n');
      }
      _currentColumn = (_currentColumn + 1) % _columnCount;
    }

    if (column < _columnWidths.length) {
      // Fixed-size column, so pad it.
      _buffer.write(text.padRight(_columnWidths[column]));
    } else {
      // The last column, so just write it.
      _buffer.write(text);
    }

    // Advance to the next column.
    _currentColumn = (_currentColumn + 1) % _columnCount;

    // If we reached the last column, we need to wrap to the next line.
    if (column == _columnCount - 1) _newlinesNeeded++;
  }

  String _buildAllowedList(final ConfigOptionBase option) {
    final isDefault = option.defaultValue() is List
        ? (option.defaultValue() as List).contains
        : (final String value) => value == option.defaultValue();

    final allowedBuffer = StringBuffer();
    allowedBuffer.write('[');
    var first = true;
    for (final a in option.allowedValues!) {
      final allowed = '$a';
      if (!first) allowedBuffer.write(', ');
      allowedBuffer.write(allowed);
      if (isDefault(allowed)) {
        allowedBuffer.write(' (default)');
      }
      first = false;
    }
    allowedBuffer.write(']');
    return allowedBuffer.toString();
  }
}
