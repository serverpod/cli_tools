enum DoubleDashHandling {
  /// No special handling means it is treated as any other word.
  noSpecialHandling,

  /// When `--` is not taken as an option value, leave the following
  /// arguments unparsed. A `--` used as a value does not start this,
  /// so a later `--` still can.
  passThroughRest,
}

class ParserSettings {
  /// How to handle a standalone `--`.
  final DoubleDashHandling doubleDashHandling;

  /// The maximum edit distance allowed when suggesting possible intended
  /// commands.
  ///
  /// Set to `0` in order to disable suggestions, defaults to `2`.
  final int suggestionDistanceLimit;

  const ParserSettings({
    this.doubleDashHandling = DoubleDashHandling.noSpecialHandling,
    this.suggestionDistanceLimit = 2,
  });
}
