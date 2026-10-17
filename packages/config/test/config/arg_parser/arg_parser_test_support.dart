import 'package:config/config.dart';
import 'package:config/src/config/arg_parser/arg_parser.dart';

ArgParseResult<OptionDefinition> childResult(
  final ArgParseResult<OptionDefinition> result,
) {
  return result.child!;
}

class TestCommand implements CommandDefinition<OptionDefinition> {
  TestCommand({
    required this.name,
    this.usage = const CommandUsageDefinition(description: ''),
    this.aliases = const CommandAliasesDefinition(),
    this.persistentOptions = const [],
    this.options = const [],
    this.subcommands = const [],
    this.canRunAsLeafCommand = false,
  });

  @override
  final String name;

  @override
  final CommandUsageDefinition usage;

  @override
  final CommandAliasesDefinition aliases;

  @override
  final List<OptionDefinition> persistentOptions;

  @override
  final List<OptionDefinition> options;

  @override
  final List<CommandDefinition> subcommands;

  @override
  final bool canRunAsLeafCommand;
}
