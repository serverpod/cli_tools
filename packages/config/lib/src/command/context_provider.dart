/// A type-keyed bag of values shared for one command run.
///
/// The type argument of [fetch], [maybeFetch], [has], [store], and [remove]
/// is the slot. `store<Logger>(StdOutLogger())` is retrieved with
/// `fetch<Logger>()`, including when the value's runtime type is a subtype.
abstract interface class ContextProvider {
  factory ContextProvider([final Map<Type, Object>? values]) =
      _MapContextProvider;

  /// Returns the value stored under `T`.
  ///
  /// Throws [ContextValueNotFound] when the slot is empty or holds a value
  /// that is not a `T`.
  T fetch<T extends Object>();

  /// Returns the value stored under `T`, or null when [fetch] would throw.
  T? maybeFetch<T extends Object>();

  /// Whether a value of type `T` is stored.
  bool has<T extends Object>();

  /// Stores [value] under `T`, replacing any previous value in that slot.
  void store<T extends Object>(final T value);

  /// Removes the value stored under `T`, if any.
  void remove<T extends Object>();
}

/// Thrown when [ContextProvider.fetch] finds no value of the requested type.
class ContextValueNotFound implements Exception {
  /// The type argument passed to [ContextProvider.fetch].
  final Type type;

  ContextValueNotFound(this.type);

  @override
  String toString() => '$runtimeType: No $type value is stored in the context.';
}

class _MapContextProvider implements ContextProvider {
  final Map<Type, Object> _values;

  _MapContextProvider([final Map<Type, Object>? values])
    : _values = values == null
          ? <Type, Object>{}
          : Map<Type, Object>.of(values);

  @override
  T fetch<T extends Object>() {
    final value = maybeFetch<T>();
    if (value == null) throw ContextValueNotFound(T);
    return value;
  }

  @override
  T? maybeFetch<T extends Object>() {
    final value = _values[T];
    return value is T ? value : null;
  }

  @override
  bool has<T extends Object>() => maybeFetch<T>() != null;

  @override
  void store<T extends Object>(final T value) => _values[T] = value;

  @override
  void remove<T extends Object>() => _values.remove(T);
}
