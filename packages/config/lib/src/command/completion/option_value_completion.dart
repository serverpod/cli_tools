import 'dart:async' show Future, FutureOr;

import '../../config/arg_parser/arg_parser.dart' show CommandDefinition;
import '../../config/arg_parser_facade.dart' show ParsedArgs;
import '../../config/completion.dart';
import '../../config/options.dart' show OptionDefinition;
import '../command_context.dart';
import '../command_resolver.dart';
import '../context_provider.dart';
import 'command_completion_context.dart';

/// The command line state for one option-value completion.
///
/// [parsedArgs] is the parse of the words including a placeholder for the
/// value being completed. Configurations are resolved from [precedingWords]
/// only, so that placeholder is not a resolved option value.
class CompletionPrelude {
  final String wordToComplete;
  final List<String> precedingWords;
  final List<CommandDefinition> commands;
  final ParsedArgs parsedArgs;
  final Map<String, String> environment;

  const CompletionPrelude({
    required this.wordToComplete,
    required this.precedingWords,
    required this.commands,
    required this.parsedArgs,
    required this.environment,
  });
}

/// Completes an option value after resolving the command line typed so far.
///
/// Uses [resolver] for the configurations, then runs the middleware of those
/// commands in [CommandRunMode.completion]. [complete] is called where the
/// leaf command's `run` would run, so each middleware's `onRun` has finished
/// and its `onReturn` runs afterwards. No command `run` method is called.
class OptionValueCompletion<O extends OptionDefinition, T> {
  final CommandResolver<O, T> resolver;

  const OptionValueCompletion(this.resolver);

  Future<CompletionResult> completeOption(
    final CompletionPrelude prelude,
    final FutureOr<CompletionResult> Function(CompletionContext context)
    complete,
  ) async {
    final contexts = resolver.resolveConfigurations(
      prelude.precedingWords,
      prelude.environment,
      ContextProvider(),
      allowIncomplete: true,
      runMode: CommandRunMode.completion,
    );

    CompletionResult? result;
    await _runMiddlewares(contexts, (final leaf) async {
      final pending = complete(
        CommandCompletionContext(
          leafContext: leaf,
          wordToComplete: prelude.wordToComplete,
          precedingWords: prelude.precedingWords,
          commands: prelude.commands,
          parsedArgs: prelude.parsedArgs,
          environment: prelude.environment,
        ),
      );
      result = pending is Future<CompletionResult> ? await pending : pending;
    });
    return result ?? const CompletionResult.none();
  }

  /// Runs the middleware of each command on [context]'s chain, outermost
  /// first, and invokes [complete] at the leaf.
  FutureOr<T?> _runMiddlewares(
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
}
