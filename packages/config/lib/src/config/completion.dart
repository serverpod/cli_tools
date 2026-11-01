import 'arg_parser/arg_parser.dart' show CommandDefinition;
import 'arg_parser_facade.dart' show ParsedArgs;

/// A single command line completion alternative.
///
/// [value] is the text inserted on the command line.
/// [description] is shown next to the value by shells that support it
/// (zsh, fish, PowerShell, Carapace). Bash ignores it.
class CompletionCandidate {
  final String value;
  final String? description;

  const CompletionCandidate(this.value, {this.description});

  @override
  bool operator ==(final Object other) {
    if (identical(this, other)) return true;
    return other is CompletionCandidate &&
        other.value == value &&
        other.description == description;
  }

  @override
  int get hashCode => Object.hash(value, description);

  @override
  String toString() {
    final desc = description;
    return desc == null
        ? 'CompletionCandidate($value)'
        : 'CompletionCandidate($value: $desc)';
  }
}

/// How the shell should complete file system paths.
enum CompletionPathMode {
  /// No file system completion.
  none,

  /// Complete files (and directories, to allow navigating into them).
  files,

  /// Complete directories only.
  directories,
}

/// What to offer when completing the value of an option.
///
/// Either a list of [candidates], or a request for the shell to perform its
/// native file system completion (which handles quoting, `~` expansion, and
/// relative paths much better than a program can).
///
/// Use the named constructors:
/// - [CompletionResult.values] for an explicit list of alternatives
/// - [CompletionResult.strings] for an explicit list of plain string values
/// - [CompletionResult.files] for native file completion
/// - [CompletionResult.directories] for native directory completion
/// - [CompletionResult.none] to offer nothing
class CompletionResult {
  /// The explicit completion alternatives. Empty for path completion.
  final List<CompletionCandidate> candidates;

  /// Whether, and how, the shell should complete file system paths.
  final CompletionPathMode pathMode;

  /// File name extensions (without the leading dot) to restrict
  /// [CompletionPathMode.files] completion to. Empty means all files.
  final List<String> fileExtensions;

  /// If true, the shell is asked not to append a space after inserting a
  /// single matching candidate. Useful for candidates that are prefixes of
  /// longer values, e.g. `host:`.
  final bool noSpace;

  /// Offers the given [candidates].
  const CompletionResult.values(
    this.candidates, {
    this.noSpace = false,
  }) : pathMode = CompletionPathMode.none,
       fileExtensions = const [];

  /// Offers the given plain string [values], without descriptions.
  CompletionResult.strings(
    final Iterable<String> values, {
    this.noSpace = false,
  }) : candidates = [for (final value in values) CompletionCandidate(value)],
       pathMode = CompletionPathMode.none,
       fileExtensions = const [];

  /// Requests native file completion from the shell,
  /// optionally restricted to the given file name [extensions]
  /// (without the leading dot).
  const CompletionResult.files({
    final List<String>? extensions,
  }) : candidates = const [],
       pathMode = CompletionPathMode.files,
       fileExtensions = extensions ?? const [],
       noSpace = false;

  /// Requests native directory completion from the shell.
  const CompletionResult.directories()
    : candidates = const [],
      pathMode = CompletionPathMode.directories,
      fileExtensions = const [],
      noSpace = false;

  /// Offers nothing.
  const CompletionResult.none()
    : candidates = const [],
      pathMode = CompletionPathMode.none,
      fileExtensions = const [],
      noSpace = false;

  @override
  String toString() =>
      'CompletionResult(candidates: $candidates, pathMode: $pathMode, '
      'fileExtensions: $fileExtensions, noSpace: $noSpace)';
}

/// The state of the command line being completed,
/// provided to `ConfigOptionBase.complete`.
///
/// Only the command line arguments are available; option values are not
/// resolved from environment variables, configuration files or the
/// configuration broker, and are not validated, because completion must be
/// fast and must never fail. The raw [environment] is available for custom
/// completions that depend on it.
class CompletionContext {
  /// The partial text of the value being completed. May be empty.
  ///
  /// For a multi-value option with a separator, this is the text after the
  /// last separator.
  final String wordToComplete;

  /// The complete words preceding the word being completed,
  /// not including the executable name.
  final List<String> precedingWords;

  /// The commands on the command line so far, root command first.
  final List<CommandDefinition> commands;

  /// The raw command line arguments parsed so far, for all commands on the
  /// command line. Option values are the strings as typed, unvalidated.
  final ParsedArgs parsedArgs;

  /// The environment variables of the completion request, i.e. of the shell
  /// asking for completion. Not used by the built-in completions; available
  /// for custom `complete` implementations, e.g. to find a server URL.
  final Map<String, String> environment;

  const CompletionContext({
    required this.wordToComplete,
    required this.precedingWords,
    required this.commands,
    required this.parsedArgs,
    required this.environment,
  });

  /// The command the completed option belongs to on this command line,
  /// i.e. the last command.
  CommandDefinition get command => commands.last;
}
