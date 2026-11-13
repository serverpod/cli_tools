/// Command line scanning and parsing.
library;

export 'command_definition.dart';
export 'parser.dart'
    show
        ArgParseResult,
        scanAndParseArgs,
        scanAndParseCommands,
        subcommandRequiredErrorPrefix,
        unknownSubcommandErrorPrefix;
export 'parser_settings.dart';
export 'scanner.dart' show optionAwaitingValue;
