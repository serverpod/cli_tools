/// The type of source that an option's value was resolved from.
enum ValueSourceType {
  /// The option has no value.
  noValue,

  /// The value was preset via code rather than normally resolved.
  preset,

  /// The value was parsed from command-line arguments.
  arg,

  /// The value was parsed from environment variables.
  envVar,

  /// The value was parsed from a configuration file.
  config,

  /// The value was provided by a custom callback.
  custom,

  /// The value is the default for the option.
  defaultValue,
}
