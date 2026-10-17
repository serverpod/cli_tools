class ContextProvider {
  final Map<Type, Object> _context;

  ContextProvider({final Map<Type, Object>? initialContext})
    : _context = initialContext ?? {};

  T fetch<T extends Object>() => _context[T] as T;

  void store<T extends Object>(final T value) => _context[T] = value;

  void remove<T extends Object>(final T value) => _context.remove(T);
}
