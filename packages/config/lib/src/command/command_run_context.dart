import '../../config.dart' show OptionDefinition, Configuration;
import 'abstract_command.dart';
import 'context_provider.dart';

/// The configuration context for the individual command being run.
///
/// The contexts for the commands on the command line form a linked list
/// via the prev and next fields.
class RunCommandContext<O extends OptionDefinition, T> {
  final AbstractCommand<O, T> command;

  final Configuration<O> config;

  /// The context of the preceding command on the command line.
  /// Null if this is the root command.
  final RunCommandContext<OptionDefinition, T>? prev;

  /// The context of the succeeding command on the command line.
  /// Null if this is the leaf command.
  late final RunCommandContext<OptionDefinition, T>? next;

  /// Shortcut to the root command's configuration, i.e. the global config.
  final Configuration globalConfig;

  final ContextProvider? provider;

  RunCommandContext({
    required this.command,
    required this.config,
    required this.prev,
    required this.provider,
  }) : globalConfig = prev?.root().config ?? config;

  RunCommandContext<O, T> copyWith({
    final AbstractCommand<O, T>? command,
    final Configuration<O>? config,
    final RunCommandContext<OptionDefinition, T>? prev,
    final RunCommandContext<OptionDefinition, T>? next,
    final ContextProvider? provider,
  }) {
    return RunCommandContext<O, T>(
      command: command ?? this.command,
      config: config ?? this.config,
      prev: prev ?? this.prev,
      provider: provider ?? this.provider,
    )..next = next ?? this.next;
  }

  /// Returns the root command's context.
  RunCommandContext<OptionDefinition, T> root() {
    final prevContext = prev;
    return prevContext == null ? this : prevContext.root();
  }

  /// Returns the leaf command's context.
  RunCommandContext<OptionDefinition, T> leaf() {
    final nextContext = next;
    return nextContext == null ? this : nextContext.leaf();
  }
}
