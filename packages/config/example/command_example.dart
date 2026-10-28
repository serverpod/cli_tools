import 'dart:async' show FutureOr;
import 'dart:io' show exit;

import 'package:config/command.dart';
import 'package:config/config.dart';

Future<void> main(final List<String> args) async {
  const utcOption = FlagOption(
    argName: 'utc',
    argAbbrev: 'u',
    helpText: 'Display timestamps in UTC timezone instead of local.',
    negatable: true,
    defaultsTo: false,
    envName: 'COMMAND_EXAMPLE_DISPLAY_UTC',
  );

  const sizeOption = IntOption(
    argName: 'size',
    argAbbrev: 's',
    argAliases: ['c', 'scope'],
    // argPos: 0,
    envName: 'COMMAND_EXAMPLE_SIZE',
    configKeys: ['size'],
    helpText:
        'Excercises option usage formatting asdf asdf asdf asfd asdf asdf'
        ' asdf asdf asdf asdf asdf asdf asdf.',
    // mandatory: true,
    defaultsTo: 1024,
    valueHelp: 'value-help',
    allowedValues: [1024, 2048, 4096, 8192, 16384],
    // allowedHelp: {
    //   '1024': '1KB',
    //   '2048': '2KB',
    //   '4096': '4KB',
    //   '8192': '8KB',
    // },
    min: 1024,
    max: 16384,
  );

  bool analyticsEnabled() => true;
  void onAnalyticsEvent(
    final String event, {
    final Map<String, dynamic>? properties,
  }) {
    print('Analytics event: $event, properties: $properties');
  }

  final runner = CommandRunner<OptionDefinition, int>(
    'command_example',
    'A simple example using CommandRunner and Command',
    globalOptions: [sizeOption, CommandRunnerBuiltinOptions.help],
    subcommands: [
      CommandImpl.withRunFunction(
        name: 'date',
        description: 'Display the current date',
        options: [utcOption],
        run: (final CommandContext runContext) {
          final utc = runContext.config.value(utcOption);
          final date = utc ? DateTime.timestamp() : DateTime.now();
          print(date.toIso8601String());
          return null;
        },
      ),
      CommandImpl.withRunFunction(
        name: 'version',
        aliases: ['--version', '-v'],
        description: 'Display the version',
        run: (final CommandContext runContext) {
          print('version 1.0.0');
          return 0;
        },
      ),
    ],
    usageOutput: UsageOutputHandler(
      exceptionSettings: const UsageExceptionSettings(
        // noUsageException: true,
        // noUsageExceptionOutput: true,
      ),
      addExceptionHandlers: [
        UsageExceptions.simpleHandler(
          (_, _, _) => makeAnalyticsSender(analyticsEnabled, onAnalyticsEvent)(
            'invalid',
          ),
        ),
      ],
    ),
    // canRunAsLeafCommand: true,
    middlewares: [
      Middlewares.onBeforeRun((final ctx) {
        makeAnalyticsSender(analyticsEnabled, onAnalyticsEvent)(
          ctx.command.name,
          // properties: buildCommandPropertiesForAnalytics(
          //   topLevelResults: topLevelResults,
          //   argParser: argParser,
          //   commands: commands,
          // ),
        );
      }),
    ],
  );

  try {
    final result = await runner.execute(args);
    print('>>> result: $result');
    if (result is int) {
      exit(result);
    }
  } on UsageException {
    print('\nUsage exception, exiting with code 1');
    exit(1);
  }
}

/// A function type for tracking events.
typedef OnAnalyticsEvent =
    void Function(
      String event, {
      Map<String, dynamic>? properties,
    });

OnAnalyticsEvent makeAnalyticsSender(
  final bool Function() analyticsEnabled,
  final OnAnalyticsEvent onAnalyticsEvent,
) {
  return (
    final String event, {
    final Map<String, dynamic>? properties,
  }) {
    if (analyticsEnabled()) {
      try {
        onAnalyticsEvent.call(event, properties: properties);
      } catch (_) {
        // Silently ignore analytics sending errors to not disrupt the main flow
      }
    }
  };
}

// TODO: A middleware example that spans the start and return of the command.
class SentryMiddleware<O extends OptionDefinition, T>
    extends CommandMiddlewareHooks<O, T> {
  const SentryMiddleware();

  @override
  FutureOr<CommandContext<O, T>> onRun(final CommandContext<O, T> ctx) {
    // foobar

    return ctx;
  }
}
