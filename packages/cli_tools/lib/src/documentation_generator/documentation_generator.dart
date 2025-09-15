import '../../better_command_runner.dart' show BetterCommandRunner;

class CommandDocumentationGenerator {
  final BetterCommandRunner commandRunner;

  CommandDocumentationGenerator(this.commandRunner);

  Map<String, String> generateMarkdown() {
    final commands = commandRunner.commands.values;

    final files = <String, String>{};

    for (final command in commands) {
      final StringBuffer markdown = StringBuffer();
      markdown.writeln('## Usage\n');

      if (command.argParser.options.isNotEmpty) {
        markdown.writeln('```console');
        markdown.writeln(command.usage);
        markdown.writeln('```\n');
      }

      if (command.subcommands.isNotEmpty) {
        final numberOfSubcommands = command.subcommands.length;
        markdown.writeln('### Sub commands\n');
        for (final (i, subcommand) in command.subcommands.entries.indexed) {
          markdown.writeln('#### `${subcommand.key}`\n');
          markdown.writeln('```console');
          markdown.writeln(subcommand.value.usage);
          markdown.writeln('```');
          if (i < numberOfSubcommands - 1) {
            markdown.writeln();
          }
        }
      }

      files['${command.name}.md'] = markdown.toString();
    }

    return files;
  }
}
