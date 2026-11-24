import 'dart:async' show Future, FutureOr;

import '../../config/options.dart' show OptionDefinition;
import '../command_context.dart';
import '../command_resolver.dart';
import '../context_provider.dart';

/// Completes where the leaf command's `run` would run.
///
/// Resolves the configurations of [precedingWords], the command line typed
/// so far, with [resolver], then runs the middleware of those commands in
/// [CommandRunMode.completion]. [complete] is called at the leaf, so each
/// middleware's `onRun` has finished and its `onReturn` runs afterwards.
/// No command `run` method is called.
///
/// [provider] is the context provider passed to `CommandRunner.run`, or the
/// empty one that run creates when the caller omits it.
///
/// Returns null if a middleware did not call its next handler.
Future<R?> completeAtLeaf<O extends OptionDefinition, T, R>(
  final CommandResolver<O, T> resolver, {
  required final List<String> precedingWords,
  required final Map<String, String> environment,
  required final ContextProvider provider,
  required final FutureOr<R> Function(
    CommandContext<OptionDefinition, T> leaf,
  )
  complete,
}) async {
  final contexts = resolver.resolveConfigurations(
    precedingWords,
    environment,
    provider,
    runMode: CommandRunMode.completion,
  );

  R? result;
  await _runMiddlewares<T>(contexts, (final leaf) async {
    result = await complete(leaf);
  });
  return result;
}

/// Runs the middleware of each command on [context]'s chain, outermost
/// first, and invokes [complete] at the leaf.
FutureOr<T?> _runMiddlewares<T>(
  final CommandContext<OptionDefinition, T> context,
  final Future<void> Function(CommandContext<OptionDefinition, T> leaf)
  complete,
) {
  final next = context.next == null
      ? (final CommandContext<OptionDefinition, T> forwarded) async {
          await complete(forwarded);
          return null;
        }
      : (final CommandContext<OptionDefinition, T> forwarded) {
          final child = forwarded.next;
          if (child == null) {
            throw StateError(
              '${forwarded.command.name} has no following command.',
            );
          }
          return _runMiddlewares(child, complete);
        };

  return context.command.runCommand(context, runNextCommand: next);
}
