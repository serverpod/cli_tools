/// The type of source that an option's value was resolved from.
enum ValueSourceType {
  noValue,
  preset,
  arg,
  envVar,
  config,
  custom,
  defaultValue,
}
