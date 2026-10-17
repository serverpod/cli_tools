typedef Handler<R, A> = R Function(A arg);

typedef Middleware<R, A> = Handler<R, A> Function(Handler<R, A> next);

class MiddlewareChain<R, A> {
  final List<Middleware<R, A>> _middlewares;

  MiddlewareChain([final List<Middleware<R, A>>? middlewares])
    : _middlewares = List.from(middlewares ?? []);

  /// Adds a middleware to the end of this chain.
  void addMiddleware(final Middleware<R, A> middleware) {
    _middlewares.add(middleware);
  }

  /// Returns a handler that runs this middleware chain with [terminalHandler]
  /// at the end.
  Handler<R, A> handlerChain(final Handler<R, A> terminalHandler) =>
      _nextHandler(_middlewares.iterator, terminalHandler);

  Handler<R, A> _nextHandler(
    final Iterator<Middleware<R, A>> mwIter,
    final Handler<R, A> terminalHandler,
  ) {
    if (mwIter.moveNext()) {
      final middleware = mwIter.current;
      return middleware(_nextHandler(mwIter, terminalHandler));
    }
    return terminalHandler;
  }
}
