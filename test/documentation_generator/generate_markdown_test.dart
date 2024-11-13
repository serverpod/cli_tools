import 'package:args/command_runner.dart';
import 'package:cli_tools/cli_tools.dart';
import 'package:test/test.dart';

class AddSpiceCommand extends Command {
  @override
  final String name = 'add';

  @override
  final String description = 'Add something to the spice mix';

  AddSpiceCommand() {
    argParser.addOption('curry', help: 'Include curry in the spice mix.');
    argParser.addOption('pepper', help: 'Include pepper in the spice mix.');
  }

  @override
  void run() {}
}

class RemoveSpiceCommand extends Command {
  @override
  final String name = 'remove';

  @override
  final String description = 'Remove something from the spice mix';

  RemoveSpiceCommand() {
    argParser.addOption('curry', help: 'Remove curry from the spice mix.');
    argParser.addOption('pepper', help: 'Remove pepper from the spice mix.');
  }

  @override
  void run() {}
}

class AddVegetableCommand extends Command {
  @override
  final String name = 'add';

  @override
  final String description = 'Add a vegetable to your dish.';

  AddVegetableCommand() {
    argParser.addOption('carrot', help: 'Adds a fresh carrot to the dish.');
  }

  @override
  void run() {}
}

class SpiceCommand extends BetterCommand {
  @override
  final String name = 'spice';

  @override
  final String description = 'Modifies the spice mix in your dish.';

  SpiceCommand() {
    addSubcommand(AddSpiceCommand());
    addSubcommand(RemoveSpiceCommand());
  }

  @override
  void run() {}
}

class VegetableCommand extends BetterCommand {
  @override
  final String name = 'vegetable';

  @override
  final String description = 'Add or remove vegatables to your dish.';

  VegetableCommand() {
    addSubcommand(AddVegetableCommand());
  }

  @override
  void run() {}
}

void main() {
  group('Given commands when generating markdown', () {
    late Map<String, String> output;

    setUpAll(() async {
      var commandRunner =
          BetterCommandRunner('cookcli', 'A cli to create wonderful dishes.')
            ..addCommand(SpiceCommand())
            ..addCommand(VegetableCommand());
      var generator = CommandDocumentationGenerator(commandRunner);
      output = generator.generateMarkdown();
    });

    test('then outputs each command into a separate file', () {
      expect(output.keys, containsAll(['vegetable.md', 'spice.md']));
    });

    test('then output starts with the main command', () async {
      var vegetableCommandOutput = output['spice.md'];

      expect(
          vegetableCommandOutput,
          startsWith(
            '## Usage\n'
            '\n'
            '```console\n'
            'Modifies the spice mix in your dish.\n'
            '\n'
            'Usage: cookcli spice <subcommand> [arguments]\n'
            '-h, --help    Print this usage information.\n'
            '\n'
            'Available subcommands:\n'
            '  add      Add something to the spice mix\n'
            '  remove   Remove something from the spice mix\n'
            '\n'
            'Run "cookcli help" to see global options.\n'
            '```\n'
            '\n',
          ));
    });

    test('then output ends with the sub commands', () async {
      var vegetableCommandOutput = output['spice.md'];

      expect(
          vegetableCommandOutput,
          endsWith(
            '### Sub commands\n'
            '\n'
            '#### `add`\n'
            '\n'
            '```console\n'
            'Add something to the spice mix\n'
            '\n'
            'Usage: cookcli spice add [arguments]\n'
            '-h, --help      Print this usage information.\n'
            '    --curry     Include curry in the spice mix.\n'
            '    --pepper    Include pepper in the spice mix.\n'
            '\n'
            'Run "cookcli help" to see global options.\n'
            '```\n'
            '\n'
            '#### `remove`\n'
            '\n'
            '```console\n'
            'Remove something from the spice mix\n'
            '\n'
            'Usage: cookcli spice remove [arguments]\n'
            '-h, --help      Print this usage information.\n'
            '    --curry     Remove curry from the spice mix.\n'
            '    --pepper    Remove pepper from the spice mix.\n'
            '\n'
            'Run "cookcli help" to see global options.\n'
            '```\n',
          ));
    });
  });
}
