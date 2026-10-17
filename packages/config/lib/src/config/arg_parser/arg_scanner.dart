import 'package:characters/characters.dart';

sealed class Argument {
  final String string;

  /// The original command-line argument this token was scanned from.
  ///
  /// Several tokens can share one [raw] value, for example `--option=value`
  /// or a cluster of short options.
  final String raw;

  /// Whether this token continues [raw] after an earlier token from the same
  /// argument.
  final bool continuesRaw;

  const Argument(
    this.string, {
    required this.raw,
    this.continuesRaw = false,
  });
}

sealed class OptionArg extends Argument {
  const OptionArg(
    super.string, {
    required super.raw,
    super.continuesRaw,
  });
}

class ShortOptionArg extends OptionArg {
  const ShortOptionArg(
    super.string, {
    required super.raw,
    super.continuesRaw,
  });
}

class LongOptionArg extends OptionArg {
  const LongOptionArg(
    super.string, {
    required super.raw,
    super.continuesRaw,
  });
}

/// Maybe a value, maybe a command.
class WordArg extends Argument {
  const WordArg(
    super.string, {
    required super.raw,
    super.continuesRaw,
  });
}

/// An argument that is definitely a value.
class ValueArg extends WordArg {
  const ValueArg(
    super.string, {
    required super.raw,
    super.continuesRaw,
  });
}

/// Special case - the `--` double dash argument.
/// Often this is used to separate the following arguments,
/// for example not parse them and instead pass them to another program.
class DoubleDashArg extends ValueArg {
  const DoubleDashArg() : super('--', raw: '--');
}

/// Special case - the `-` single dash argument.
/// Some commands attribute special meaning to `-`, such as referring to
/// stdin/stdout.
class SingleDashArg extends ValueArg {
  const SingleDashArg() : super('-', raw: '-');
}

class UnparsedArg extends Argument {
  const UnparsedArg(
    super.string, {
    required super.raw,
    super.continuesRaw,
  });
}

enum DoubleDashHandling {
  /// No special handling means it is treated as any other word.
  noSpecialHandling,

  /// When `--` is not taken as an option value, leave the following
  /// arguments unparsed. A `--` used as a value does not start this,
  /// so a later `--` still can.
  passThroughRest,
}

class ScanMode {
  final DoubleDashHandling doubleDashHandling;

  const ScanMode({
    this.doubleDashHandling = DoubleDashHandling.noSpecialHandling,
  });
}

/// Scans a list of argument strings and returns a list of [Argument]s.
///
/// Does not validate and does not throw [Exception]s.
///
/// ### Argument syntaxes
///
/// These are the possible argument syntaxes.
///
/// "Chars" are one or more characters with each representing an option
/// abbreviation.
///
/// "Word" can be a command or a value, this depends on the previous argument
/// and whether it is an option that actually takes a value, and also whether
/// positional argument values are accepted at this position.
///
/// Note that a word/value may be an empty string.
/// ```
/// word
/// -chars
/// --option
/// -chars value
/// --option value
/// -chars=value
/// --option=value
/// --
/// -
/// ```
///
/// When an option takes a value, the following argument is that value even if
/// it starts with a hyphen, so `--number -123` yields `-123`.
/// Attached values use the `=` syntax (`--number=-123`).
///
/// No escapes are supported.
///
/// ### Assumptions
///
/// These constraints apply to option names and abbreviations. They are not
/// checked by this scanner, but are assumed to be followed.
/// - Option names / abbreviations cannot contain '='.
/// - Commands and option names / abbreviations cannot start with '-'.
List<Argument> scanArgs(final Iterable<String> args) {
  final List<Argument> scanned = [];
  final argsIterator = args.iterator;
  while (argsIterator.moveNext()) {
    _scanNext(scanned, argsIterator);
  }
  return scanned;
}

void _scanNext(
  final List<Argument> scanned,
  final Iterator<String> args,
) {
  final arg = args.current;

  if (arg.startsWith('--')) {
    if (arg.length == 2) {
      scanned.add(const DoubleDashArg());
      return;
    }

    final equalIndex = arg.indexOf('=');
    if (equalIndex != -1) {
      scanned.add(LongOptionArg(arg.substring(2, equalIndex), raw: arg));
      scanned.add(
        ValueArg(
          arg.substring(equalIndex + 1),
          raw: arg,
          continuesRaw: true,
        ),
      );
      return;
    }

    scanned.add(LongOptionArg(arg.substring(2), raw: arg));
    return;
  }

  if (arg.startsWith('-')) {
    if (arg.length == 1) {
      scanned.add(const SingleDashArg());
      return;
    }

    var continued = false;
    for (final (_, ch) in arg.substring(1).characters.indexed) {
      if (ch == '=') {
        final equalIndex = arg.indexOf('=');
        scanned.add(
          ValueArg(
            arg.substring(equalIndex + 1),
            raw: arg,
            continuesRaw: continued,
          ),
        );
        return;
      }
      scanned.add(
        ShortOptionArg(
          ch,
          raw: arg,
          continuesRaw: continued,
        ),
      );
      continued = true;
    }
    return;
  }

  scanned.add(WordArg(arg, raw: arg));
}
