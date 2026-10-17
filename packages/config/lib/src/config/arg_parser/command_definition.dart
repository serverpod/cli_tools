import '../options.dart' show OptionDefinition;

abstract interface class CommandDefinition<O extends OptionDefinition> {
  /// The name of this command.
  String get name;

  /// Describes usage documentation and visibility for this command.
  CommandUsageDefinition get usage;

  /// Describes alternate names resolution for this command.
  CommandAliasesDefinition get aliases;

  /// Persistent options - the options of the current command that continue to
  /// be available for all subcommands.
  /// On the root command, this is the global options.
  List<O> get persistentOptions;

  /// Regular options - the options of the current command that are not
  /// persistent.
  List<O> get options;

  List<CommandDefinition> get subcommands;

  /// Whether this command can be run as the last command on the command line
  /// even if it has subcommands registered. Default is false.
  /// If false and this command is the last command found on the command line,
  /// the command line parser will yield an error.
  bool get canRunAsLeafCommand => false;
}

class CommandUsageDefinition {
  /// A description of this command, included in usage.
  final String description;

  /// An optional footer which is added to the end of the usage.
  final String? usageFooter;

  /// The command's category.
  ///
  /// Displayed in [parent]'s [CommandRunner.usage]. Commands with categories
  /// will be grouped together, and displayed after commands without a category.
  final String? category;

  /// Whether or not this command should be hidden from help listings.
  ///
  /// By default, leaf commands are always visible. Branch commands are visible
  /// as long as any of their leaf commands are visible.
  final bool hidden;

  const CommandUsageDefinition({
    required this.description,
    this.usageFooter,
    this.category,
    final bool? hidden,
  }) : hidden = hidden ?? false;
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

  /// The maximum edit distance allowed when suggesting possible intended
  /// commands.
  ///
  /// Set to `0` in order to disable suggestions, defaults to `2`.
  final int suggestionDistanceLimit;

  const CommandAliasesDefinition({
    final List<String>? aliases,
    final List<String>? suggestionAliases,
    final int? suggestionDistanceLimit,
  }) : aliases = aliases ?? const <String>[],
       suggestionAliases = suggestionAliases ?? const <String>[],
       suggestionDistanceLimit = suggestionDistanceLimit ?? 2;
}
