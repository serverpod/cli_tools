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

/// A [Command] is a named task on the command line.
/// It is a "branch" command if it has subcommands, otherwise it is a "leaf" command.
/// Leaf commands have a [run] method that is called when the command is executed.
///
/// All commands can have middlewares that are executed before and after
/// their subcommands and run method.
///
/// All commands can have options. For a branch command, the options are
/// "persistent", i.e. they are available anywhere to the right on the command
/// line (across any subcommands). Leaf command options can be positional,
/// i.e. directly as values without being prefixed by an option name.
/// (Branch commands can't have positional options as they would conflict with
/// subcommand names.)
///
/// See also [CommandImpl] for easy set up of [Command] objects via parameters
/// rather than overriding fields.
///
/// See also [BridgeCommand] if migrating from the legacy args package, extend
/// from it instead of the old Command class to make the transition easier.
abstract class Command<O extends OptionDefinition, T>
    extends AbstractCommand<O, T> {
  CommandUsageDefinition? _usageDefinition;
  CommandAliasesDefinition? _aliasesDefinition;

  /// Returns the usage definition this command was constructed with, or the
  /// default blank one.
  /// Override this method to provide a dynamic usage definition.
  @override
  CommandUsageDefinition get usageDefinition =>
      _usageDefinition ??= const CommandUsageDefinition();

  /// Returns the aliases definition this command was constructed with, or the
  /// default blank one.
  /// Override this method to provide a dynamic aliases definition.
  @override
  CommandAliasesDefinition get aliasesDefinition =>
      _aliasesDefinition ??= const CommandAliasesDefinition();

  Command({
    final CommandUsageDefinition? usageDefinition,
    final CommandAliasesDefinition? aliasesDefinition,
    final UsageGenerator? usageGenerator,
    super.persistentOptions,
    super.options,
    super.subcommands,
    super.middlewares,
    super.canRunAsLeafCommand,
  }) : _usageDefinition = usageDefinition,
       _aliasesDefinition = aliasesDefinition,
       super(
         usageGenerator:
             usageGenerator ?? const StandardCommandUsageGenerator(),
       );

  @override
  FutureOr<T?> runAsLeaf(final CommandContext<O, T> context) {
    return run(context);
  }

  /// Runs this command as a leaf command. Implemented by subclasses.
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
  CommandUsageDefinition get usageDefinition =>
      _usageDefinition ??= CommandUsageDefinition(
        description: description,
        usageFooter: usageFooter,
        category: category,
        hidden: hidden,
      );

  @override
  CommandAliasesDefinition get aliasesDefinition =>
      _aliasesDefinition ??= CommandAliasesDefinition(
        aliases: aliases,
        suggestionAliases: suggestionAliases,
      );

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
       );

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

  bool get takesArguments =>
      allOptions().any((final option) => option.option.argPos != null);

  void printUsage() => runner.usageOutput.printUsage(this);

  Never usageException(final String message) =>
      throw UsageException(message, usage);
}

/// The type of the [Command.run] method.
typedef CommandRunFunction<O extends OptionDefinition, T> =
    FutureOr<T?> Function(CommandContext<O, T> context);

/// A parameterized implementation of [Command] for easy set up
/// of a command object via parameters rather than overriding fields.
///
/// Classes extending this must override the [run] method.
/// If you don't need a class at all, use [CommandImpl.branch], or
/// [CommandImpl.leafWithRunFunction] with a run function.
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
         ),
       );

  /// Creates a new branch command (i.e. a command with subcommands) via
  /// parameters rather than writing a class and overriding its fields.
  static CommandImpl<O, T> branch<O extends OptionDefinition, T>({
    required final String name,
    required final String description,
    final String? usageFooter,
    final String? category,
    final bool? hidden,
    final List<String>? aliases,
    final List<String>? suggestionAliases,
    final List<CommandMiddleware<O, T>>? middlewares,
    final List<O>? persistentOptions,
    final List<Command<OptionDefinition, T>>? subcommands,
    final bool canRunAsLeafCommand = false,
  }) {
    return _CommandWithRunFunction(
      name: name,
      description: description,
      usageFooter: usageFooter,
      category: category,
      hidden: hidden,
      aliases: aliases,
      suggestionAliases: suggestionAliases,
      middlewares: middlewares,
      persistentOptions: persistentOptions,
      subcommands: subcommands,
      canRunAsLeafCommand: canRunAsLeafCommand,
      run: (final CommandContext<O, T> context) {
        throw UnsupportedError(
          'Branch command ${context.command.name} should not be run()',
        );
      },
    );
  }

  /// Creates a new leaf command via parameters rather than writing a class and
  /// overriding its fields.
  static CommandImpl<O, T> leafWithRunFunction<O extends OptionDefinition, T>({
    required final String name,
    required final String description,
    final String? usageFooter,
    final String? category,
    final bool? hidden,
    final List<String>? aliases,
    final List<String>? suggestionAliases,
    final List<O>? options,
    final List<CommandMiddleware<O, T>>? middlewares,
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
      middlewares: middlewares,
      options: options,
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
    required super.middlewares,
    super.persistentOptions,
    super.options,
    super.subcommands,
    super.canRunAsLeafCommand,
    required final CommandRunFunction<O, T> run,
  }) : _run = run;

  @override
  FutureOr<T?> run(final CommandContext<O, T> context) {
    return _run(context);
  }
}
