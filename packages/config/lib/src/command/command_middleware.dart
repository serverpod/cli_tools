import 'dart:async' show FutureOr;

import '../../middleware.dart';
import '../config/config.dart' show OptionDefinition;
import 'command_context.dart';

typedef CommandHandler<O extends OptionDefinition, T> =
    Handler<FutureOr<T?>, CommandContext<O, T>>;

typedef CommandMiddleware<O extends OptionDefinition, T> =
    Middleware<FutureOr<T?>, CommandContext<O, T>>;

/// Convenience class for easier type binding of [MiddlewareHooks] for commands.
class CommandMiddlewareHooks<O extends OptionDefinition, T>
    extends MiddlewareHooks<T?, CommandContext<O, T>> {
  const CommandMiddlewareHooks();
}

/// Convenience class for easier type binding of [MiddlewareComposer] for commands.
class CommandMiddlewareComposer<O extends OptionDefinition, T>
    extends MiddlewareComposer<T?, CommandContext<O, T>> {
  const CommandMiddlewareComposer({
    super.onRun,
    super.onReturn,
    super.onError,
  });
}

/// Convenience methods for creating [CommandMiddleware]s.
abstract class Middlewares {
  /// Factory function to create a [CommandMiddleware] with the given hooks.
  static CommandMiddleware<O, T> withHooks<O extends OptionDefinition, T>({
    final OnRun<CommandContext<O, T>>? onRun,
    final OnReturn<T?, CommandContext<O, T>>? onReturn,
    final OnError<T?, CommandContext<O, T>>? onError,
  }) {
    return CommandMiddlewareComposer<O, T>(
      onRun: onRun,
      onReturn: onReturn,
      onError: onError,
    ).middleware;
  }

  /// Creates a [CommandMiddleware] with a variant of [onRun] that does not
  /// return a value, intended for use before the command is run but no need to
  /// change the context.
  static CommandMiddleware<O, T> onBeforeRun<O extends OptionDefinition, T>(
    final FutureOr<void> Function(CommandContext<O, T>) onRun,
  ) {
    return Middlewares.withHooks(
      onRun: (final ctx) async {
        onRun(ctx);
        return ctx;
      },
    );
  }

  /// Creates a [CommandMiddleware] with the given [onRun] hook.
  ///
  /// See [MiddlewareHooks.onRun].
  static CommandMiddleware<O, T> onRun<O extends OptionDefinition, T>(
    final OnRun<CommandContext<O, T>> onRun,
  ) {
    return Middlewares.withHooks(onRun: onRun);
  }

  /// Creates a [CommandMiddleware] with the given [onReturn] hook.
  ///
  /// See [MiddlewareHooks.onReturn].
  static CommandMiddleware<O, T> onReturn<O extends OptionDefinition, T>(
    final OnReturn<T?, CommandContext<O, T>> onReturn,
  ) {
    return Middlewares.withHooks(onReturn: onReturn);
  }

  /// Creates a [CommandMiddleware] with the given [onError] hook.
  ///
  /// See [MiddlewareHooks.onError].
  static CommandMiddleware<O, T> onError<O extends OptionDefinition, T>(
    final OnError<T?, CommandContext<O, T>> onError,
  ) {
    return Middlewares.withHooks(onError: onError);
  }
}
