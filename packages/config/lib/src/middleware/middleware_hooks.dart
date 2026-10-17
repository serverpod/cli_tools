import 'dart:async' show FutureOr;

import 'middleware.dart';

/// Base class for easy creation of [Middleware] hooks.
class MiddlewareHooks<T, A> {
  const MiddlewareHooks();

  /// Middleware method that produces the handler that runs these hooks.
  /// Adheres to the [Middleware] signature.
  Handler<FutureOr<T>, A> middleware(final Handler<FutureOr<T>, A> next) {
    return (final A arg) async {
      final useArg = await onRun(arg);
      final T response;
      try {
        response = await next(useArg);
      } catch (error, stackTrace) {
        return await onError(error, stackTrace, useArg);
      }
      return await onReturn(useArg, response);
    };
  }

  /// Hook method that is called before the next handler is run.
  ///
  /// The returned value is passed to the next handler.
  ///
  /// If it throws, the call chain is aborted
  /// and the exception propagates to the caller.
  FutureOr<A> onRun(final A arg) {
    return arg;
  }

  /// Hook method that is called after the next handler returns normally.
  ///
  /// Returns the same type as the next handler's return type.
  /// By default the response is returned unchanged.
  ///
  /// If it throws, the call chain is aborted
  /// and the exception propagates to the caller.
  FutureOr<T> onReturn(final A arg, final T response) {
    return response;
  }

  /// Hook method that is called if the next handler throws.
  ///
  /// Returns the same type as the next handler's return type.
  ///
  /// If it throws, the call chain is aborted
  /// and the exception propagates to the caller.
  FutureOr<T> onError(
    final Object error,
    final StackTrace stackTrace,
    final A arg,
  ) {
    Error.throwWithStackTrace(error, stackTrace);
  }
}

typedef OnRun<A> = FutureOr<A> Function(A arg);
typedef OnReturn<T, A> = FutureOr<T> Function(A arg, T response);
typedef OnError<T, A> =
    FutureOr<T> Function(Object error, StackTrace stackTrace, A arg);

/// Helper class for easy composition with hook functions.
class MiddlewareComposer<T, A> extends MiddlewareHooks<T, A> {
  final OnRun<A>? _onRun;
  final OnReturn<T, A>? _onReturn;
  final OnError<T, A>? _onError;

  /// Compose a middleware with one or more hook functions.
  const MiddlewareComposer({
    final OnRun<A>? onRun,
    final OnReturn<T, A>? onReturn,
    final OnError<T, A>? onError,
  }) : _onRun = onRun,
       _onReturn = onReturn,
       _onError = onError;

  @override
  FutureOr<A> onRun(final A arg) {
    final onRun = _onRun;
    if (onRun == null) return arg;
    return onRun(arg);
  }

  @override
  FutureOr<T> onReturn(final A arg, final T response) {
    final onReturn = _onReturn;
    if (onReturn == null) return response;
    return onReturn(arg, response);
  }

  @override
  FutureOr<T> onError(
    final Object error,
    final StackTrace stackTrace,
    final A arg,
  ) {
    if (_onError != null) {
      return _onError.call(error, stackTrace, arg);
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
}
