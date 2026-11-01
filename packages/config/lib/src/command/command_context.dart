import '../../config.dart' show OptionDefinition, Configuration;
import 'abstract_command.dart';
import 'builtin_global_option.dart';
import 'context_provider.dart';

/// The configuration context for the individual command being run.
///
/// The contexts for the commands on the command line form a linked list
/// via the prev and next fields.
class CommandContext<O extends OptionDefinition, T> {
  final AbstractCommand<O, T> command;

  /// The configuration of the command's own (application-defined) options.
  final Configuration<O> config;

  /// The configuration of the command's built-in options,
  /// see `CommandDefinition.builtinPersistentOptions`.
  /// Empty for commands without built-in options.
  final Configuration<BuiltinGlobalOption> builtinConfig;

  /// The context of the preceding command on the command line.
  /// Null if this is the root command.
  final CommandContext<OptionDefinition, T>? prev;

  /// The context of the succeeding command on the command line.
  /// Null if this is the leaf command.
  late final CommandContext<OptionDefinition, T>? next;

  /// Shortcut to the root command's configuration, i.e. the global config.
  final Configuration globalConfig;

  /// User-defined provider.
  final ContextProvider? provider;

  CommandContext({
    required this.command,
    required this.config,
    required this.prev,
    required this.provider,
    final Configuration<BuiltinGlobalOption>? builtinConfig,
  }) : builtinConfig =
           builtinConfig ??
           Configuration<BuiltinGlobalOption>.fromValues(values: const {}),
       globalConfig = prev?.root().config ?? config;

  CommandContext<O, T> copyWith({
    final AbstractCommand<O, T>? command,
    final Configuration<O>? config,
    final Configuration<BuiltinGlobalOption>? builtinConfig,
    final CommandContext<OptionDefinition, T>? prev,
    final CommandContext<OptionDefinition, T>? next,
    final ContextProvider? provider,
  }) {
    return CommandContext<O, T>(
      command: command ?? this.command,
      config: config ?? this.config,
      builtinConfig: builtinConfig ?? this.builtinConfig,
      prev: prev ?? this.prev,
      provider: provider ?? this.provider,
    )..next = next ?? this.next;
  }

  /// Returns the root command's context.
  CommandContext<OptionDefinition, T> root() {
    final prevContext = prev;
    return prevContext == null ? this : prevContext.root();
  }

  /// Returns the leaf command's context.
  CommandContext<OptionDefinition, T> leaf() {
    final nextContext = next;
    return nextContext == null ? this : nextContext.leaf();
  }
}
