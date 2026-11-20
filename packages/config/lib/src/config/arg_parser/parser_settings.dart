enum DoubleDashHandling {
  /// No special handling means it is treated as any other word.
  noSpecialHandling,

  /// Every argument after a `--` is left unparsed, unless the `--` is consumed
  /// as an option value (in which case a later `--` still stops parsing).
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
