abstract interface class ContextProvider {
  T fetch<T>();

  void store<T>(final T value);
}
