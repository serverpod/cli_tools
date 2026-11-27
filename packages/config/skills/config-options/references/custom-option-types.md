# Custom option types and completion of values

- [Choose the smallest form](#choose-the-smallest-form)
- [Specialize an existing type](#specialize-an-existing-type)
- [A new value type](#a-new-value-type)
- [Completion of option values](#completion-of-option-values)

## Choose the smallest form

| Need | Form |
|---|---|
| One extra check on one option | `customValidator` on that option |
| A fixed set of values | `EnumOption`, or `allowedValues` on any type |
| The same constraints or completion on several options | A subclass of an existing type |
| A value of a Dart type that the package has no option for | A `ValueParser` and a subclass of `ConfigOptionBase` |

## Specialize an existing type

```dart
/// A TCP port.
class PortOption extends IntOption {
  const PortOption({
    super.argName,
    super.envName,
    super.configKey,
    super.defaultsTo,
    super.helpText,
    super.mandatory,
  }) : super(min: 1, max: 65535, valueHelp: 'port');
}
```

The constructor is `const` and forwards the parameters that the options of this type use.

## A new value type

```dart
class UriParser extends ValueParser<Uri> {
  const UriParser();

  @override
  Uri parse(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) {
      throw FormatException('"$value" is not an absolute URI');
    }
    return uri;
  }
}

class UriOption extends ConfigOptionBase<Uri> {
  const UriOption({
    super.argName,
    super.argAbbrev,
    super.argPos,
    super.envName,
    super.configKey,
    super.defaultsTo,
    super.helpText,
    super.valueHelp = 'uri',
    super.customValidator,
    super.mandatory,
    this.schemes,
  }) : super(valueParser: const UriParser());

  /// The accepted URI schemes. Null accepts every scheme.
  final List<String>? schemes;

  @override
  void validateValue(Uri value) {
    super.validateValue(value);
    final schemes = this.schemes;
    if (schemes != null && !schemes.contains(value.scheme)) {
      throw InvalidValueException(
        'The scheme must be one of ${schemes.join(', ')}',
      );
    }
  }

  @override
  CompletionResult complete(CompletionContext context) {
    return CompletionResult.strings([
      for (final scheme in schemes ?? const <String>[]) '$scheme://',
    ], noSpace: true);
  }
}
```

It is used like a built-in type, and `config.value(ConnectOption.server)` is a `Uri`:

```dart
server(
  UriOption(
    argName: 'server',
    envName: 'SERVER_URL',
    schemes: ['http', 'https'],
    mandatory: true,
    helpText: 'The server to connect to.',
  ),
),
```

- **Parser.** `parse` turns the text of any source into the value and throws a `FormatException` for text that is malformed. The message of the exception is shown to the user after `Invalid value for option "--server" <uri>:`. Override `format` when `toString` of the value is not the text that the usage should show for a default.
- **Validation.** `validateValue` calls `super.validateValue(value)` first, which applies `allowedValues` and `customValidator`. It throws a `FormatException` or an `InvalidValueException`.
- **Ordered values.** A type that implements `Comparable` extends `ComparableValueOption<V>`, which adds `min` and `max`.
- **Model.** The built-in types in `lib/src/config/option_types.dart` and `file_system_options.dart` of the package are short and follow this same structure.

## Completion of option values

Shell completion of a value asks the option. The default offers the `allowedValues`, or the keys of `allowedHelp`. Without those it asks the shell for file names, which suits an option whose value is a path. `EnumOption`, `FileOption`, `DirOption`, and `FlagOption` have their own behavior.

An option with other values overrides `complete`:

```dart
/// The name of a profile. Completion offers the names of the existing ones.
class ProfileOption extends StringOption {
  const ProfileOption({super.argName, super.envName, super.helpText});

  @override
  Future<CompletionResult> complete(CompletionContext context) async {
    final profiles = await loadProfiles();
    return CompletionResult.values([
      for (final profile in profiles)
        CompletionCandidate(profile.name, description: profile.region),
    ]);
  }
}
```

| Result | Offers |
|---|---|
| `CompletionResult.strings(names)` | The strings |
| `CompletionResult.values(candidates)` | Values with descriptions |
| `CompletionResult.files(extensions: ['yaml', 'yml'])` | File names from the shell |
| `CompletionResult.directories()` | Directory names from the shell |
| `CompletionResult.none()` | Nothing, for a free text value |

- `complete` returns fast and catches its own failures. When it throws, nothing is offered.
- The shell filters the alternatives by the typed prefix.
- `noSpace: true` suits alternatives that the user continues typing after, such as `https://`.
- In a program built on the command framework, `complete` can read the options and the stored objects of the command line typed so far. See "Custom completion for an option type" in `README_command.md` of the package.
