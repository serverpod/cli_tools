import 'package:characters/characters.dart';

sealed class Token {
  final String string;

  const Token(this.string);
}

sealed class OptionToken extends Token {
  const OptionToken(super.string);
}

class ShortOptionToken extends OptionToken {
  const ShortOptionToken(super.string);
}

class LongOptionToken extends OptionToken {
  const LongOptionToken(super.string);
}

/// Maybe a value, maybe a command.
class WordToken extends Token {
  const WordToken(super.string);
}

/// A token that is definitely a value.
class ValueToken extends WordToken {
  const ValueToken(super.string);
}

/// Special case - the `--` double dash argument.
/// Often this is used to separate the following arguments,
/// for example not parse them and instead pass them to another program.
final class DoubleDashToken extends ValueToken {
  const DoubleDashToken() : super('--');
}

/// Special case - the `-` single dash argument.
/// Some commands attribute special meaning to `-`, such as referring to
/// stdin/stdout.
final class SingleDashToken extends ValueToken {
  const SingleDashToken() : super('-');
}

/// One command-line argument and the tokens the scanner cut from it.
final class ScannedArg {
  final String raw;
  final List<Token> tokens;

  const ScannedArg(this.raw, this.tokens);
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

/// Scans command-line arguments into one [ScannedArg] per argument.
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
/// - Option names / abbreviations cannot start with '-'.
///
/// A command name may itself be option syntax (`--version`, `-v`). This
/// scanner still classifies that argument as an option, but the parser may
/// then select it as a subcommand when no option matches.
List<ScannedArg> scanArgs(final Iterable<String> args) => [
  for (final arg in args) ScannedArg(arg, _scanTokens(arg)),
];

/// If [arg] is written as an option that would take its value from the
/// next argument, returns the spelling of that option: `--name` for a
/// long option or `-x` for a short option (the last one of a cluster
/// such as `-abx`).
///
/// Returns null for words, for `--` and `-`, and for options with an
/// attached value (`--name=value`, `-x=value`), since those cannot take
/// the next argument as their value. Whether the option actually takes
/// a value is up to the caller.
String? optionAwaitingValue(final String arg) {
  final tokens = _scanTokens(arg);
  if (tokens.isEmpty) return null;
  return switch (tokens.last) {
    LongOptionToken(:final string) => '--$string',
    ShortOptionToken(:final string) => '-$string',
    _ => null,
  };
}

List<Token> _scanTokens(final String arg) {
  if (arg == '--') return const [DoubleDashToken()];
  if (arg == '-') return const [SingleDashToken()];

  final equalIndex = arg.indexOf('=');
  final hasValue = equalIndex != -1;
  final nameEnd = hasValue ? equalIndex : arg.length;
  final value = [if (hasValue) ValueToken(arg.substring(equalIndex + 1))];

  if (arg.startsWith('--')) {
    return [LongOptionToken(arg.substring(2, nameEnd)), ...value];
  }
  if (arg.startsWith('-')) {
    return [
      for (final ch in arg.substring(1, nameEnd).characters)
        ShortOptionToken(ch),
      ...value,
    ];
  }
  return [WordToken(arg)];
}
