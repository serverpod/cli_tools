import '../../config/completion.dart';
import '../../config/options.dart' show OptionDefinition;
import '../command_context.dart';

/// A [CompletionContext] that carries the command contexts resolved for
/// the words typed so far.
///
/// Produced by the command runner when completing an option value.
/// [leafContext] is the last command, after that command's middleware
/// `onRun`. [CommandContext.runMode] is [CommandRunMode.completion].
/// Ancestors are [CommandContext.prev]. [CommandContext.provider] is shared
/// by the chain; middleware publishes services there for
/// `ConfigOptionBase.complete` to fetch.
class CommandCompletionContext<T> extends CompletionContext {
  /// The leaf command context after its middleware `onRun`.
  final CommandContext<OptionDefinition, T> leafContext;

  CommandCompletionContext({
    required this.leafContext,
    required super.wordToComplete,
    required super.precedingWords,
    required super.commands,
    required super.parsedArgs,
    required super.environment,
  });
}

/// The leaf [CommandContext] resolved for this completion, if the command
/// runner prepared one.
///
/// Null when completion did not resolve the command line.
///
/// [T] is the command runner's result type. Omit the type arguments to
/// accept whatever result type was used.
///
/// Walk [CommandContext.prev] toward the root. Root options, including
/// global options, are on [CommandContext.root]. The leaf command's own
/// options are on the returned context.
CommandContext<O, T>? commandContextOf<O extends OptionDefinition, T>(
  final CompletionContext context,
) {
  if (context is! CommandCompletionContext<T>) return null;
  final leaf = context.leafContext;
  if (leaf is CommandContext<O, T>) return leaf;
  return null;
}
