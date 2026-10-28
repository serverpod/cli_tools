import 'dart:collection' show SplayTreeMap;
import 'dart:math' as math;

import '../../config/config.dart' show OptionDefinition;
import '../abstract_command.dart' show AbstractCommand;
import '../command_runner.dart' show RootCommandRunner;
import 'invocation_synopsis.dart' show commandInvocationSynopsis;
import 'options_usage.dart';

const _usagePrefix = 'Usage: ';

String _runnerInvocation(final AbstractCommand command) =>
    '${command.name} [global-options] <command> [arguments]';

/// Generates a string showing usage information for a command.
String commandUsage(
  final AbstractCommand command,
  final bool isSubcommand,
  final int? lineLength,
) {
  final headline = _wrapText(
    command.usageDefinition.description,
    length: lineLength,
    hangingIndent: null,
  );

  final invocation = isSubcommand
      ? commandInvocationSynopsis(command)
      : _runnerInvocation(command);

  final buffer = StringBuffer()
    ..writeln(headline)
    ..writeln()
    ..writeln(
      _usagePrefix +
          _wrapText(
            invocation,
            length: lineLength,
            hangingIndent: _usagePrefix.length,
          ),
    )
    ..writeln();

  if (command.persistentOptions.isNotEmpty) {
    buffer.writeln(
      getOptionsUsage(
        command.persistentOptions,
        isSubcommand: isSubcommand,
        isPersistentOptions: true,
        lineLength: lineLength,
      ),
    );
  }

  if (command.options.isNotEmpty) {
    buffer.writeln(
      getOptionsUsage(
        command.options,
        isSubcommand: isSubcommand,
        isPersistentOptions: false,
        lineLength: lineLength,
      ),
    );
  }

  if (command.subcommands.isNotEmpty) {
    buffer
      ..writeln(
        getCommandUsage(
          command.subcommands,
          isSubcommand: isSubcommand,
          lineLength: lineLength,
        ),
      )
      ..writeln();

    if (!isSubcommand) {
      buffer.writeln(
        _wrapText(
          'Run "${command.name} help <command>" for more information about a command.',
          length: lineLength,
          hangingIndent: null,
        ),
      );
    }
  }

  if (isSubcommand) {
    buffer.writeln(
      _wrapText(
        'Run "${command.runner.name} help" to see global options.',
        length: lineLength,
        hangingIndent: null,
      ),
    );
  }

  if (command.usageDefinition.usageFooter != null) {
    buffer.writeln(_makeFooter(command, lineLength));
  }
  return buffer.toString();
}

String getOptionsUsage(
  final List<OptionDefinition> options, {
  final bool isSubcommand = false,
  final bool isPersistentOptions = false,
  final int? lineLength,
}) {
  final optionsHeading = isSubcommand
      ? isPersistentOptions
            ? 'Persistent options:'
            : 'Options:'
      : isPersistentOptions
      ? 'Global options:'
      : 'Options:';

  //final optionsUsage = generateOptionsUsage(options, lineLength: lineLength);
  final optionsUsage = OptionsUsageGenerator(
    options,
    lineLength: lineLength,
    addGroupSeparators: true,
  ).generate();

  final buffer = StringBuffer()
    ..writeln(
      _wrapText(
        optionsHeading,
        length: lineLength,
        hangingIndent: null,
      ),
    )
    ..write(optionsUsage);

  return buffer.toString();
}

/// Returns a string representation of [commands] fit for use in a usage string.
///
/// [isSubcommand] indicates whether the commands should be called "commands" or
/// "subcommands".
String getCommandUsage(
  final List<AbstractCommand> cmds, {
  final bool isSubcommand = false,
  final int? lineLength,
}) {
  final commands = {
    for (final cmd in cmds) cmd.name: cmd,
  };
  var names = commands.keys;

  // Filter out hidden ones, unless they are all hidden.
  final visible = names.where(
    (final name) => !commands[name]!.usageDefinition.hidden,
  );
  if (visible.isNotEmpty) names = visible;

  // Show the commands alphabetically.
  names = names.toList()..sort();

  // Group the commands by category.
  final commandsByCategory = SplayTreeMap<String, List<AbstractCommand>>();
  for (final name in names) {
    final category = commands[name]!.usageDefinition.category ?? '';
    commandsByCategory.putIfAbsent(category, () => []).add(commands[name]!);
  }
  final categories = commandsByCategory.keys.toList();

  final length = names.map((final name) => name.length).reduce(math.max);

  final buffer = StringBuffer(
    'Available ${isSubcommand ? "sub" : ""}commands:',
  );
  final columnStart = length + 5;
  for (final category in categories) {
    if (category != '') {
      buffer.writeln();
      buffer.writeln();
      buffer.write(category);
    }
    for (final command in commandsByCategory[category]!) {
      final lines = wrapTextAsLines(
        _summary(command),
        start: columnStart,
        length: lineLength,
      );
      buffer.writeln();
      buffer.write('  ${_padRight(command.name, length)}   ${lines.first}');

      for (final line in lines.skip(1)) {
        buffer.writeln();
        buffer.write(' ' * columnStart);
        buffer.write(line);
      }
    }
  }

  return buffer.toString();
}

String _makeFooter(final AbstractCommand command, final int? lineLength) {
  final formattedFooter = _wrapText(
    command.usageDefinition.usageFooter!,
    length: lineLength,
    hangingIndent: null,
  );
  return '\n$formattedFooter';
}

String _summary(final AbstractCommand command) =>
    command.usageDefinition.description.split('\n').first;

/// Pads [source] to [length] by adding spaces at the end.
String _padRight(final String source, final int length) =>
    source + ' ' * (length - source.length);

/// Wraps a block of text into lines no longer than [length].
///
/// Tries to split at whitespace, but if that's not good enough to keep it
/// under the limit, then it splits in the middle of a word.
///
/// Preserves indentation (leading whitespace) for each line (delimited by '\n')
/// in the input, and indents wrapped lines the same amount.
///
/// If [hangingIndent] is supplied, then that many spaces are added to each
/// line, except for the first line. This is useful for flowing text with a
/// heading prefix (e.g. "Usage: "):
///
/// ```dart
/// var prefix = "Usage: ";
/// print(
///   prefix + wrapText(invocation, hangingIndent: prefix.length, length: 40),
/// );
/// ```
///
/// yields:
/// ```
/// Usage: app main_command <subcommand>
///        [arguments]
/// ```
///
/// If [length] is not specified, then no wrapping occurs, and the original
/// [text] is returned unchanged.
String _wrapText(final String text, {final int? length, int? hangingIndent}) {
  if (length == null) return text;
  hangingIndent ??= 0;
  final splitText = text.split('\n');
  final result = <String>[];
  for (final line in splitText) {
    var trimmedText = line.trimLeft();
    final leadingWhitespace = line.substring(
      0,
      line.length - trimmedText.length,
    );
    List<String> notIndented;
    if (hangingIndent != 0) {
      // When we have a hanging indent, we want to wrap the first line at one
      // width, and the rest at another (offset by hangingIndent), so we wrap
      // them twice and recombine.
      final firstLineWrap = wrapTextAsLines(
        trimmedText,
        length: length - leadingWhitespace.length,
      );
      notIndented = [firstLineWrap.removeAt(0)];
      trimmedText = trimmedText.substring(notIndented[0].length).trimLeft();
      if (firstLineWrap.isNotEmpty) {
        notIndented.addAll(
          wrapTextAsLines(
            trimmedText,
            length: length - leadingWhitespace.length - hangingIndent,
          ),
        );
      }
    } else {
      notIndented = wrapTextAsLines(
        trimmedText,
        length: length - leadingWhitespace.length,
      );
    }
    String? hangingIndentString;
    result.addAll(
      notIndented.map<String>((final String line) {
        // Don't return any lines with just whitespace on them.
        if (line.isEmpty) return '';
        final result = '${hangingIndentString ?? ''}$leadingWhitespace$line';
        hangingIndentString ??= ' ' * hangingIndent!;
        return result;
      }),
    );
  }
  return result.join('\n');
}

/// Wraps a block of text into lines no longer than [length],
/// starting at the [start] column, and returns the result as a list of strings.
///
/// Tries to split at whitespace, but if that's not good enough to keep it
/// under the limit, then splits in the middle of a word. Preserves embedded
/// newlines, but not indentation (it trims whitespace from each line).
///
/// If [length] is not specified, then no wrapping occurs, and the original
/// [text] is returned after splitting it on newlines. Whitespace is not trimmed
/// in this case.
List<String> wrapTextAsLines(
  final String text, {
  final int start = 0,
  final int? length,
}) {
  assert(start >= 0);

  /// Returns true if the code unit at [index] in [text] is a whitespace
  /// character.
  ///
  /// Based on: https://en.wikipedia.org/wiki/Whitespace_character#Unicode
  bool isWhitespace(final String text, final int index) {
    final rune = text.codeUnitAt(index);
    return rune >= 0x0009 && rune <= 0x000D ||
        rune == 0x0020 ||
        rune == 0x0085 ||
        rune == 0x1680 ||
        rune == 0x180E ||
        rune >= 0x2000 && rune <= 0x200A ||
        rune == 0x2028 ||
        rune == 0x2029 ||
        rune == 0x202F ||
        rune == 0x205F ||
        rune == 0x3000 ||
        rune == 0xFEFF;
  }

  if (length == null) return text.split('\n');

  final result = <String>[];
  final effectiveLength = math.max(length - start, 10);
  for (var line in text.split('\n')) {
    line = line.trim();
    if (line.length <= effectiveLength) {
      result.add(line);
      continue;
    }

    var currentLineStart = 0;
    int? lastWhitespace;
    for (var i = 0; i < line.length; ++i) {
      if (isWhitespace(line, i)) lastWhitespace = i;

      if (i - currentLineStart >= effectiveLength) {
        // Back up to the last whitespace, unless there wasn't any, in which
        // case we just split where we are.
        if (lastWhitespace != null) i = lastWhitespace;

        result.add(line.substring(currentLineStart, i).trim());

        // Skip any intervening whitespace.
        while (isWhitespace(line, i) && i < line.length) {
          i++;
        }

        currentLineStart = i;
        lastWhitespace = null;
      }
    }
    result.add(line.substring(currentLineStart).trim());
  }
  return result;
}
