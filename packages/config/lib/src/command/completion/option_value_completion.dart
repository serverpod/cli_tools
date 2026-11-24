import 'dart:async' show Future, FutureOr;

import '../../config/arg_parser/arg_parser.dart' show CommandDefinition;
import '../../config/arg_parser_facade.dart' show ParsedArgs;
import '../../config/completion.dart';
import '../../config/options.dart' show OptionDefinition;
import '../command_resolver.dart';
import '../context_provider.dart';
import 'command_completion_context.dart';
import 'completion_at_leaf.dart';

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
/// commands in completion mode. [complete] is called where the leaf command's
/// `run` would run, so each middleware's `onRun` has finished and its
/// `onReturn` runs afterwards. No command `run` method is called.
/// See [completeAtLeaf].
class OptionValueCompletion<O extends OptionDefinition, T> {
  final CommandResolver<O, T> resolver;

  const OptionValueCompletion(this.resolver);

  /// Resolves [prelude] with [provider] and runs that chain's middleware.
  ///
  /// [provider] is the context provider passed to `CommandRunner.run`, or the
  /// empty one that run creates when the caller omits it.
  Future<CompletionResult> completeOption(
    final CompletionPrelude prelude,
    final FutureOr<CompletionResult> Function(CompletionContext context)
    complete, {
    required final ContextProvider provider,
  }) async {
    final result = await completeAtLeaf(
      resolver,
      precedingWords: prelude.precedingWords,
      environment: prelude.environment,
      provider: provider,
      complete: (final leaf) => complete(
        CommandCompletionContext(
          leafContext: leaf,
          wordToComplete: prelude.wordToComplete,
          precedingWords: prelude.precedingWords,
          commands: prelude.commands,
          parsedArgs: prelude.parsedArgs,
          environment: prelude.environment,
        ),
      ),
    );
    return result ?? const CompletionResult.none();
  }
}
