import 'package:config/config.dart';

ArgParseResult<OptionDefinition> childResult(
  final ArgParseResult<OptionDefinition> result,
) {
  return result.child!;
}

class TestCommand implements CommandDefinition<OptionDefinition> {
  TestCommand({
    required this.name,
    this.usageDefinition = const CommandUsageDefinition(description: ''),
    this.aliasesDefinition = const CommandAliasesDefinition(),
    this.persistentOptions = const [],
    this.builtinPersistentOptions = const [],
    this.options = const [],
    this.subcommands = const [],
    this.canRunAsLeafCommand = false,
  });

  @override
  final String name;

  @override
  String get usage => '$name: ${usageDefinition.description}';

  @override
  final CommandUsageDefinition usageDefinition;

  @override
  final CommandAliasesDefinition aliasesDefinition;

  @override
  final List<OptionDefinition> persistentOptions;

  @override
  final List<OptionDefinition> builtinPersistentOptions;

  @override
  final List<OptionDefinition> options;

  @override
  final List<CommandDefinition> subcommands;

  @override
  final bool canRunAsLeafCommand;
}
