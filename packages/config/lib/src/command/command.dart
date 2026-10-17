import 'dart:async' show FutureOr;

import '../config/config.dart'
    show OptionDefinition, CommandUsageDefinition, CommandAliasesDefinition;
import 'abstract_command.dart';
import 'command_run_context.dart';

abstract class Command<O extends OptionDefinition, T>
    extends AbstractCommand<O, T> {
  Command({
    super.persistentOptions,
    super.options,
    super.subcommands,
    super.middlewares,
    super.canRunAsLeafCommand,
  });

  @override
  CommandAliasesDefinition get aliases => throw UnimplementedError();
}

typedef CommandHandler<O extends OptionDefinition, T> =
    FutureOr<T?> Function(
      RunCommandContext<O, T> runContext,
    );

typedef CommandMiddleware<O extends OptionDefinition, T> =
    CommandHandler<O, T> Function(
      CommandHandler<O, T> next,
    );

/// The type of the [Command.run] method.
typedef CommandRunFunction<O extends OptionDefinition, T> =
    FutureOr<T?> Function(RunCommandContext<O, T> runContext);

/// A parameterized concrete implementation of [Command] for easy use.
///
/// Classes extending this must override the [run] method.
///
/// Use [CommandImpl.withRunFunction] to create a new command with a run function.
abstract class CommandImpl<O extends OptionDefinition, T>
    extends Command<O, T> {
  @override
  final String name;

  @override
  final CommandUsageDefinition usage;

  @override
  final CommandAliasesDefinition aliases;

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
  }) : usage = CommandUsageDefinition(
         description: description,
         usageFooter: usageFooter,
         category: category,
         hidden: hidden,
       ),
       aliases = CommandAliasesDefinition(
         aliases: aliases,
         suggestionAliases: suggestionAliases,
         suggestionDistanceLimit: suggestionDistanceLimit,
       );

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
    required final CommandRunFunction<O, T> run,
  }) : _run = run;

  @override
  FutureOr<T?> run(final RunCommandContext<O, T> runContext) {
    return _run(runContext);
  }
}
