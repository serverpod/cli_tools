import '../../config.dart'
    show OptionDefinition, Configuration, ValueSourceType;
import 'abstract_command.dart';
import 'action_option.dart';
import 'builtin_global_option.dart';
import 'context_provider.dart';

/// Whether a command context is being used to run or to complete the command line.
enum CommandRunMode {
  /// The command line is being executed.
  execution,

  /// The command line is being completed.
  completion,
}

/// The configuration context for the individual command being run.
///
/// The contexts for the commands on the command line form a linked list
/// via the prev and next fields.
class CommandContext<O extends OptionDefinition, T> {
  final AbstractCommand<O, T> command;

  /// Whether this context is part of executing or completing the command line.
  final CommandRunMode runMode;

  /// The configuration of the command's own (application-defined) options.
  final Configuration<O> config;

  /// The configuration of the command's built-in options.
  /// Empty for commands without built-in options.
  final Configuration<BuiltinGlobalOption> builtinConfig;

  /// The context of the preceding command on the command line.
  /// Null if this is the root command.
  final CommandContext<OptionDefinition, T>? prev;

  /// The context of the succeeding command on the command line.
  /// Null if this is the leaf command.
  late final CommandContext<OptionDefinition, T>? next;

  /// User-defined objects / state provider.
  final ContextProvider provider;

  CommandContext({
    required this.command,
    required this.config,
    required this.prev,
    required this.provider,
    required this.runMode,
    final Configuration<BuiltinGlobalOption>? builtinConfig,
  }) : builtinConfig =
           builtinConfig ??
           Configuration<BuiltinGlobalOption>.fromValues(values: const {});

  CommandContext<O, T> copyWith({
    final AbstractCommand<O, T>? command,
    final Configuration<O>? config,
    final Configuration<BuiltinGlobalOption>? builtinConfig,
    final CommandContext<OptionDefinition, T>? prev,
    final CommandContext<OptionDefinition, T>? next,
    final ContextProvider? provider,
    final CommandRunMode? runMode,
  }) {
    return CommandContext<O, T>(
      command: command ?? this.command,
      config: config ?? this.config,
      builtinConfig: builtinConfig ?? this.builtinConfig,
      prev: prev ?? this.prev,
      provider: provider ?? this.provider,
      runMode: runMode ?? this.runMode,
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

  bool _cachedSpecifiedActionOptionIsSet = false;
  ActionOptionMixin? _cachedSpecifiedActionOption;

  /// Returns the action option of the command that was specified on the
  /// command line, if any. If non-null, it is run instead of a command.
  ActionOptionMixin? get specifiedActionOption {
    if (_cachedSpecifiedActionOptionIsSet) {
      return _cachedSpecifiedActionOption;
    }
    final allArgOptions = [
      ...builtinConfig.optionsWhereSource(
        (final ValueSourceType s) => s == ValueSourceType.arg,
      ),
      ...config.optionsWhereSource(
        (final ValueSourceType s) => s == ValueSourceType.arg,
      ),
    ];
    _cachedSpecifiedActionOption = allArgOptions
        .map((final o) => o is ActionOptionMixin ? o : o.option)
        .whereType<ActionOptionMixin>()
        .firstOrNull;
    _cachedSpecifiedActionOptionIsSet = true;
    return _cachedSpecifiedActionOption;
  }
}
