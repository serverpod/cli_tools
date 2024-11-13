import '../../better_command_runner.dart';

class CommandDocumentationGenerator {
  final BetterCommandRunner commandRunner;

  CommandDocumentationGenerator(this.commandRunner);

  Map<String, String> generateMarkdown() {
    var commands = commandRunner.commands.values;

    var files = <String, String>{};

    for (var command in commands) {
      StringBuffer markdown = StringBuffer();
      markdown.writeln('## Usage\n');

      if (command.argParser.options.isNotEmpty) {
        markdown.writeln('```console');
        markdown.writeln(command.usage);
        markdown.writeln('```\n');
      }

      if (command.subcommands.isNotEmpty) {
        var numberOfSubcommands = command.subcommands.length;
        markdown.writeln('### Sub commands\n');
        for (var (i, subcommand) in command.subcommands.entries.indexed) {
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
