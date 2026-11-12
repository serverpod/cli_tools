import '../config/config.dart'
    show ConfigOptionBase, FlagOption, OptionDefinition;

/// The built-in global options of a command runner,
/// see `CommandRunner.builtinPersistentOptions`.
enum BuiltinGlobalOption<V extends Object> implements OptionDefinition<V> {
  /// Shows the usage of the last command on the command line.
  help(
    FlagOption(
      argName: 'help',
      argAbbrev: 'h',
      negatable: false,
      helpText: 'Print this usage information.',
    ),
  );

  const BuiltinGlobalOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}
