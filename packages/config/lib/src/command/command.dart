import 'dart:async' show FutureOr;

import '../config/config.dart'
    show
        OptionDefinition,
        CommandUsageDefinition,
        CommandAliasesDefinition,
        UsageException;
import 'abstract_command.dart';
import 'command_context.dart';
import 'command_middleware.dart';
import 'usage_generator.dart'
    show StandardCommandUsageGenerator, UsageGenerator;

// TODO: Doc comment
abstract class Command<O extends OptionDefinition, T>
    extends AbstractCommand<O, T> {
  @override
  final CommandUsageDefinition usageDefinition;

  @override
  final CommandAliasesDefinition aliasesDefinition;

  Command({
    final CommandUsageDefinition? usageDefinition,
    final CommandAliasesDefinition? aliasesDefinition,
    super.persistentOptions,
    super.options,
    super.subcommands,
    super.middlewares,
    super.canRunAsLeafCommand,
    final UsageGenerator? usageGenerator,
  }) : usageDefinition = usageDefinition ?? const CommandUsageDefinition(),
       aliasesDefinition =
           aliasesDefinition ?? const CommandAliasesDefinition(),
       super(
         usageGenerator:
             usageGenerator ?? const StandardCommandUsageGenerator(),
       );

  @override
  FutureOr<T?> runAsLeaf(final CommandContext<O, T> context) {
    return run(context);
  }

  /// Runs this command. Implemented by subclasses.
  FutureOr<T?> run(final CommandContext<O, T> context);
}

/// A bridge command that closes the gap between Command and the old args
/// package's Command class.
///
/// Most of the members of the old class are present here, and they are used
/// to initialize this command.
///
/// Subclasses using the old Command class' members can extend this class to
/// make the transition to the new Command class easier. (Note that ArgParser
/// and ArgResults related members are not present, and the run method signature
/// is different, which is necessary with the modernized Command design.)
abstract class BridgeCommand<O extends OptionDefinition, T>
    extends Command<O, T> {
  @override
  // ignore: overridden_fields
  late CommandUsageDefinition usageDefinition;

  @override
  // ignore: overridden_fields
  late CommandAliasesDefinition aliasesDefinition;

  BridgeCommand({
    super.persistentOptions,
    super.options,
    super.subcommands,
    super.middlewares,
    super.canRunAsLeafCommand,
    final UsageGenerator? usageGenerator,
  }) : super(
         usageGenerator:
             usageGenerator ?? const StandardCommandUsageGenerator(),
       ) {
    usageDefinition = CommandUsageDefinition(
      description: description,
      usageFooter: usageFooter,
      category: category,
      hidden: hidden,
    );
    aliasesDefinition = CommandAliasesDefinition(
      aliases: aliases,
      suggestionAliases: suggestionAliases,
    );
  }

  /// Must be overridden by subclass.
  @override
  String get name;

  /// Must be overridden by subclass.
  String get description;

  String get category => '';

  String? get usageFooter => null;

  bool get hidden => false;

  List<String> get aliases => const [];

  List<String> get suggestionAliases => const [];

  String get summary => description.split('\n').first;

  String get invocation => subcommands.isNotEmpty
      ? '$name <subcommand> [arguments]'
      : '$name [arguments]';

  bool get takesArguments => [
    ...options,
    ...persistentOptions,
    ...builtinPersistentOptions,
  ].any((final option) => option.option.argPos != null);

  void printUsage() => runner.usageOutput.printUsage(this);

  Never usageException(final String message) =>
      throw UsageException(message, usage);
}

/// The type of the [Command.run] method.
typedef CommandRunFunction<O extends OptionDefinition, T> =
    FutureOr<T?> Function(CommandContext<O, T> context);

/// A parameterized concrete implementation of [Command] for easy set up
/// of a command object via parameters rather than overriding fields.
///
/// Classes extending this must override the [run] method.
/// If you don't need a class at all, use [CommandImpl.withRunFunction] to
/// supply the run function as a parameter instead.
abstract class CommandImpl<O extends OptionDefinition, T>
    extends Command<O, T> {
  @override
  final String name;

  CommandImpl({
    required this.name,
    required final String description,
    final String? usageFooter,
    final String? category,
    final bool? hidden,
    final List<String>? aliases,
    final List<String>? suggestionAliases,
    final int? suggestionDistanceLimit,
    super.persistentOptions,
    super.options,
    super.subcommands,
    super.middlewares,
    super.canRunAsLeafCommand,
  }) : super(
         usageDefinition: CommandUsageDefinition(
           description: description,
           usageFooter: usageFooter,
           category: category,
           hidden: hidden,
         ),
         aliasesDefinition: CommandAliasesDefinition(
           aliases: aliases,
           suggestionAliases: suggestionAliases,
           suggestionDistanceLimit: suggestionDistanceLimit,
         ),
       );

  /// Creates a new command via parameters rather than writing a class and
  /// overriding its fields.
  static CommandImpl<O, T> withRunFunction<O extends OptionDefinition, T>({
    required final String name,
    required final String description,
    final String? usageFooter,
    final String? category,
    final bool? hidden,
    final List<String>? aliases,
    final List<String>? suggestionAliases,
    final int? suggestionDistanceLimit,
    final List<O>? persistentOptions,
    final List<O>? options,
    final List<Command<OptionDefinition, T>>? subcommands,
    final List<CommandMiddleware<O, T>>? middlewares,
    final bool canRunAsLeafCommand = false,
    required final CommandRunFunction<O, T> run,
  }) {
    return _CommandWithRunFunction(
      name: name,
      description: description,
      usageFooter: usageFooter,
      category: category,
      hidden: hidden,
      aliases: aliases,
      suggestionAliases: suggestionAliases,
      suggestionDistanceLimit: suggestionDistanceLimit,
      persistentOptions: persistentOptions,
      options: options,
      subcommands: subcommands,
      middlewares: middlewares,
      canRunAsLeafCommand: canRunAsLeafCommand,
      run: run,
    );
  }
}

class _CommandWithRunFunction<O extends OptionDefinition, T>
    extends CommandImpl<O, T> {
  final CommandRunFunction<O, T> _run;

  _CommandWithRunFunction({
    required super.name,
    required super.description,
    required super.usageFooter,
    required super.category,
    required super.hidden,
    required super.aliases,
    required super.suggestionAliases,
    required super.suggestionDistanceLimit,
    required super.persistentOptions,
    required super.options,
    required super.subcommands,
    required super.middlewares,
    required super.canRunAsLeafCommand,
    required final CommandRunFunction<O, T> run,
  }) : _run = run;

  @override
  FutureOr<T?> run(final CommandContext<O, T> context) {
    return _run(context);
  }
}
