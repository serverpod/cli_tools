import '../options.dart' show OptionDefinition;

abstract interface class CommandDefinition<O extends OptionDefinition> {
  /// The name of this command.
  String get name;

  /// Generates a formatted string with usage information for this command.
  String get usage;

  /// Describes usage documentation and visibility for this command.
  CommandUsageDefinition get usageDefinition;

  /// Describes alternate names resolution for this command.
  CommandAliasesDefinition get aliasesDefinition;

  /// Persistent options - the options of the current command that continue to
  /// be available for all subcommands.
  /// On the root command, this is the global options.
  List<O> get persistentOptions;

  /// Regular options - the options of the current command that are not
  /// persistent.
  List<O> get options;

  /// All the defined options of this command, depending on the passed flag.
  List<OptionDefinition> allOptions({final bool onlyPersistent = false});

  List<CommandDefinition> get subcommands;

  /// Whether this command can be run as the last command on the command line
  /// even if it has subcommands registered. Default is false.
  /// If false and this command is the last command found on the command line,
  /// the command line parser will yield an error.
  bool get canRunAsLeafCommand => false;

  /// Whether positional arguments that match no positional option are allowed
  /// after this command. Defaults to false. Only leaf commands use this.
  bool get ignoreUnexpectedPositionalArgs => false;

  /// Whether every argument after this command is left unparsed, to be
  /// passed through to another program. Defaults to false.
  ///
  /// The arguments are not options, subcommands or option values of this
  /// command line, whatever they look like. That includes `--help` and `--`.
  ///
  /// A pass-through command must not be the root command, and must not have
  /// subcommands or command line options: the parser would never reach them.
  bool get passThroughArgs => false;
}

/// An option that is run like a subcommand when it is written on the command
/// line, see `ActionOptionMixin`.
///
abstract interface class ActionOptionDefinition<V>
    implements OptionDefinition<V> {
  /// Whether this action option takes the place of a subcommand.
  /// If true it is a usage error to write a subcommand or another
  /// exclusive action option after it.
  /// If false it can be written anywhere on the command line, like `--help`.
  bool get isExclusive;
}

class CommandUsageDefinition {
  /// A description of this command, included in usage.
  final String description;

  /// An optional footer which is added to the end of the usage.
  final String? usageFooter;

  /// The command's category.
  ///
  /// Displayed in [parent]'s usage. Commands with categories
  /// will be grouped together, and displayed after commands without a category.
  final String? category;

  /// Whether or not this command should be hidden from help listings.
  ///
  /// By default, leaf commands are always visible. Branch commands are visible
  /// as long as any of their leaf commands are visible.
  final bool hidden;

  /// A short description of this command, included in [parent]'s usage.
  /// If null, the default is used which is typically the first line of [description].
  final String? summary;

  /// A custom template for this command's own invocation, replacing its name
  /// and argument synopsis.
  ///
  /// Parent command names are prepended. If the default synopsis would be
  /// `executable branch leaf <args>`, this string replaces `leaf <args>`
  /// (for example `"leaf <package>"`). If null, the synopsis is generated.
  final String? invocation;

  const CommandUsageDefinition({
    final String? description,
    this.usageFooter,
    this.category,
    final bool? hidden,
    this.summary,
    this.invocation,
  }) : description = description ?? '',
       hidden = hidden ?? false;
}

class CommandAliasesDefinition {
  /// Alternate names for this command.
  final List<String> aliases;

  /// Alternate non-functional names for this command.
  ///
  /// These names won't be used in the documentation, and also they won't work
  /// when invoked on the command line. But if an unknown command is used it
  /// will be matched against this when creating suggestions.
  ///
  /// A name does not have to be repeated both here and in [aliases].
  final List<String> suggestionAliases;

  const CommandAliasesDefinition({
    final List<String>? aliases,
    final List<String>? suggestionAliases,
  }) : aliases = aliases ?? const <String>[],
       suggestionAliases = suggestionAliases ?? const <String>[];
}
