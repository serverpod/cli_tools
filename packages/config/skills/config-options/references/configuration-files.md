# Option values from configuration files

An option that has a `configKey` takes its value from a configuration file when neither the command line nor the environment gave one. The file is read by a `ConfigurationBroker`, which the program writes.

- [Keys and values](#keys-and-values)
- [A broker for a file that an option names](#a-broker-for-a-file-that-an-option-names)
- [With the command framework](#with-the-command-framework)
- [Several sources](#several-sources)

## Keys and values

```dart
port(
  IntOption(
    argName: 'port',
    envName: 'SERVE_PORT',
    configKey: '/server/port',
    defaultsTo: 8080,
    helpText: 'The port to listen on.',
  ),
),
```

- `ConfigurationParser.fromFile(path)` reads a `.json`, `.yaml`, or `.yml` file. `ConfigurationParser.fromString(text, format: ConfigEncoding.yaml)` reads text. Both return a `ConfigurationSource`.
- The key of such a source is a JSON pointer: `/server/port` is `port` inside `server`.
- `configKeys: ['/server/port', '/port']` tries the keys in order.
- A string in the file is parsed like a value on the command line: `timeout: 90s` for a `DurationOption`.
- A value that is not a string must already have the type of the option: a number for an `IntOption` or a `DoubleOption`, a boolean for a `FlagOption`.
- Write the value of a list option as one string with commas: `hosts: a,b`.

A value of another type, such as a YAML list, is reported as a usage error.

## A broker for a file that an option names

```dart
void _checkExtension(File file) {
  if (!RegExp(r'\.(json|ya?ml)$').hasMatch(file.path.toLowerCase())) {
    throw const FormatException('The file must be a .json or .yaml file');
  }
}

enum ServeOption<V extends Object> implements OptionDefinition<V> {
  configFile(
    FileOption(
      argName: 'config',
      envName: 'SERVE_CONFIG',
      mode: PathExistMode.mustExist,
      customValidator: _checkExtension,
      helpText: 'The configuration file.',
    ),
  ),
  port(
    IntOption(
      argName: 'port',
      envName: 'SERVE_PORT',
      configKey: '/server/port',
      defaultsTo: 8080,
      helpText: 'The port to listen on.',
    ),
  ),
  timeout(
    DurationOption(
      argName: 'timeout',
      configKey: '/server/timeout',
      helpText: 'The request timeout.',
    ),
  );

  const ServeOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

/// Reads the file that `--config` names, when that option has a value.
class ServeFileBroker implements ConfigurationBroker<ServeOption> {
  ConfigurationSource? _source;

  @override
  Object? valueOrNull(String key, Configuration<ServeOption> cfg) {
    final file = cfg.optionalValue(ServeOption.configFile);
    if (file == null) return null;
    final source = _source ??= ConfigurationParser.fromFile(file.path);
    return source.valueOrNull(key);
  }
}

Configuration<ServeOption> resolveServe(List<String> args) {
  return Configuration.resolve(
    options: ServeOption.values,
    args: args,
    env: Platform.environment,
    configBroker: ServeFileBroker(),
  );
}
```

- **Order.** The broker reads the file option from `cfg`, the configuration under construction. Declare the file option before every option that has a `configKey`.
- **One broker for one resolution.** At is good practice for a broker to lazy load on the first lookup and cache it. If resolve is called several times (e.g. in tests), then it is good practice to create a new broker for each call.
- **Return type.** `valueOrNull` returns the value as the source gives it, so numbers and booleans in the file keep their type.
- **A file that cannot be read.** `fromFile` throws an `ArgumentError` for a missing file and an `UnsupportedError` for another extension. Both are errors of the program, so the file option checks them first: `mode: PathExistMode.mustExist` and the `customValidator` above turn them into usage errors. A file with invalid JSON or YAML is reported as a usage error by the package.

## With the command framework

A command gives the broker for its own options by overriding `configBroker`. The framework calls it while it resolves the command line, before any middleware runs.

```dart
/// Reads option values from one configuration file.
class FileBroker implements ConfigurationBroker {
  FileBroker(this.file);

  final File file;
  ConfigurationSource? _source;

  @override
  Object? valueOrNull(String key, Configuration cfg) {
    final source = _source ??= ConfigurationParser.fromFile(file.path);
    return source.valueOrNull(key);
  }
}

class BuildCommand extends CommandImpl<BuildOption, int> {
  BuildCommand()
    : super(
        name: 'build',
        description: 'Builds the project.',
        options: BuildOption.values,
      );

  @override
  ConfigurationBroker? configBroker(
    CommandContext<OptionDefinition, int>? prevContext,
  ) {
    final global = prevContext!.root().config;
    final file = global.optionalValue(GlobalOption.configFile);
    return file == null ? null : FileBroker(file);
  }

  // ...
}
```

- `prevContext` is the context of the command before this one on the command line, and is null only for the runner. Its `config`, and the ones before it, are resolved. `GlobalOption.configFile` is a global `FileOption` like the one above.
- The override reads the file option without a check for errors. When that option has an error, such as a file that does not exist, the read throws an `InvalidParseStateError`, and the framework handles it: the user gets the usage error of the file option only, and no error for the options of this command that take their value from the file.
- Commands that share the file share the override through a base class.
- The runner reads its global options from the file by overriding `configBroker` in a `CommandRunner` subclass. Its `prevContext` is null, so it returns a broker like `ServeFileBroker` above, which reads the file option from `cfg`.

## Several sources

`MultiDomainConfigBroker.prefix({'local': localProvider, 'user': userProvider})` routes each key to a source by its prefix: `configKey: 'local:/port'` asks the `local` source for `/port`. Each source is a `ConfigSourceProvider`, which returns the `ConfigurationSource` and caches it. `OptionContentConfigProvider` is a ready-made provider for JSON or YAML text that is itself the value of an option.

Read the doc comment of `MultiDomainConfigBroker` in `lib/src/config/multi_config_source.dart` for the key matching, including regular expressions.
