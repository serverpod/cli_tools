import 'dart:async';

import 'package:config/command.dart';
import 'package:config/config.dart';

/// Skips printing usage errors.
///
/// Use this when a test asserts on [UsageException] and not on the printed text,
/// so a passing run does not write to the terminal.
const noUsageErrorOutput = UsageOutputHandler(
  exceptionSettings: UsageExceptionSettings(noUsageExceptionOutput: true),
);

/// Runs [runner] and collects text written with [print].
Future<({T? result, String output})>
runCapturingPrint<O extends OptionDefinition, T>(
  final CommandRunner<O, T> runner,
  final List<String> args, {
  final Map<String, String>? env,
}) async {
  final lines = <String>[];
  final result = await runZoned(
    () async => runner.runner(args, env: env),
    zoneSpecification: ZoneSpecification(
      print: (final self, final parent, final zone, final line) {
        lines.add(line);
      },
    ),
  );
  return (result: result, output: lines.join('\n'));
}

/// A command that records [name] when it runs.
///
/// [body] replaces the default result, which is the command name.
class RecordingCommand<O extends OptionDefinition>
    extends CommandImpl<O, String> {
  RecordingCommand({
    required super.name,
    required super.description,
    required this.trace,
    super.aliases,
    super.suggestionAliases,
    super.hidden,
    super.options,
    super.persistentOptions,
    super.subcommands,
    super.middlewares,
    this.body,
    this.standalone = false,
  });

  final List<String> trace;

  final FutureOr<String?> Function(
    RunCommandContext<O, String> context,
  )?
  body;

  final bool standalone;

  @override
  bool get runStandalone => standalone;

  @override
  FutureOr<String?> run(
    final RunCommandContext<O, String> runContext,
  ) {
    trace.add(name);
    final body = this.body;
    if (body != null) return body(runContext);
    return name;
  }
}

/// A runner that records its own name when the root command runs.
class TracingRunner<O extends OptionDefinition>
    extends CommandRunner<O, String> {
  TracingRunner(
    this.trace, {
    super.subcommands,
    super.middlewares,
    super.canRunAsLeafCommand,
    super.globalOptions,
    super.configBroker,
    super.ignoreUnexpectedPositionalArgs,
    super.rootFooter,
    super.usageOutput,
  }) : super('tool', 'Tools');

  final List<String> trace;

  @override
  String? run(final RunCommandContext<O, String> runContext) {
    trace.add(name);
    return name;
  }
}
