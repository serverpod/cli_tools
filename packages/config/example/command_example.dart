import 'dart:async' show FutureOr;
import 'dart:io' show exit;

import 'package:config/command.dart';
import 'package:config/config.dart';

const _version = '1.0.0';

/// A CommandRunner framework example that uses:
/// - global options, action options, and regular options
/// - middleware for usage analytics
/// - middleware for command span timing
/// - storing state on the [ContextProvider]
/// - subcommands with options and run functions
Future<void> main(final List<String> args) async {
  final dateCommand = CommandImpl.leafWithRunFunction<DateOption, int>(
    name: 'date',
    description: 'Display the current date',
    options: DateOption.values,
    run: (final CommandContext<DateOption, int> runContext) {
      final utc = runContext.config.value(DateOption.utc);
      final date = utc ? DateTime.timestamp() : DateTime.now();
      print(date.toIso8601String());
      return null;
    },
  );

  final versionCommand = CommandImpl.leafWithRunFunction<OptionDefinition, int>(
    name: 'version',
    description: 'Display the version',
    run: (final CommandContext<OptionDefinition, int> runContext) {
      print('version $_version');
      return 0;
    },
  );

  final branchCommand = CommandImpl.branch<OptionDefinition, int>(
    name: 'branch',
    description: 'Branch command with subcommands',
    subcommands: [
      CommandImpl.leafWithRunFunction<OptionDefinition, int>(
        name: 'child',
        description: 'Child command',
        run: (final CommandContext<OptionDefinition, int> runContext) {
          print('running child command');
          return 0;
        },
      ),
    ],
  );

  bool analyticsEnabled() => true;

  final runner = CommandRunner<GlobalOption, int>(
    'command_example',
    'A simple example using CommandRunner and Command',
    globalOptions: GlobalOption.values,
    subcommands: [
      dateCommand,
      versionCommand,
      branchCommand,
    ],
    canRunAsLeafCommand: true,
    // This example prints after the runner returns, which would corrupt the
    // output of a shell completion request: exit right after that instead.
    completion: const CompletionSettings(exitAfterResponse: true),
    usageOutput: UsageOutputHandler(
      addExceptionHandlers: [
        UsageExceptions.simpleHandler(
          (_, _, _) => makeAnalyticsSender(analyticsEnabled, onAnalyticsEvent)(
            'invalid',
          ),
        ),
      ],
    ),
    middlewares: [
      AnalyticsMiddleware(analyticsEnabled).middleware,
      const CommandSpanMiddleware<GlobalOption, int>().middleware,
    ],
  );

  try {
    final result = await runner.run(args);
    print('>>> result: $result');
    if (result is int) {
      exit(result);
    }
  } on UsageException {
    print('\nUsage exception, exiting with code 1');
    exit(1);
  }
}

/// `--version` / `-v`: prints the version instead of running a subcommand.
class VersionActionOption extends FlagOption with ActionOptionMixin<bool> {
  /// Creates the version action option.
  const VersionActionOption()
    : super(
        argName: 'version',
        argAbbrev: 'v',
        negatable: false,
        helpText: 'Display the version',
      );

  @override
  FutureOr<R?> run<O extends OptionDefinition, R>(
    final CommandContext<O, R> context,
  ) {
    print('version $_version');
    return null;
  }
}

/// Options of the example's root command.
enum GlobalOption<V extends Object> implements OptionDefinition<V> {
  size(
    IntOption(
      argName: 'size',
      argAbbrev: 's',
      argAliases: ['c', 'scope'],
      envName: 'COMMAND_EXAMPLE_SIZE',
      configKeys: ['size'],
      helpText:
          'Excercises option usage formatting with a long long long long long'
          ' long long long long help text.',
      defaultsTo: 1024,
      valueHelp: 'value-help',
      allowedValues: [1024, 2048, 4096, 8192, 16384],
    ),
  ),
  version(VersionActionOption());

  const GlobalOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

/// Options for the `date` command.
enum DateOption<V extends Object> implements OptionDefinition<V> {
  utc(
    FlagOption(
      argName: 'utc',
      argAbbrev: 'u',
      helpText: 'Display timestamps in UTC timezone instead of local.',
      negatable: true,
      defaultsTo: false,
      envName: 'COMMAND_EXAMPLE_DISPLAY_UTC',
    ),
  );

  const DateOption(this.option);

  @override
  final ConfigOptionBase<V> option;
}

///////////////
// Analytics example

/// A function type for tracking events.
typedef OnAnalyticsEvent =
    void Function(
      String event, {
      Map<String, dynamic>? properties,
    });

/// Prints an analytics event. Stands in for a real analytics client.
void onAnalyticsEvent(
  final String event, {
  final Map<String, dynamic>? properties,
}) {
  print('Analytics event: $event, properties: $properties');
}

/// Returns an [OnAnalyticsEvent] that sends events only when analytics is on.
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

/// Sends the command name before the command line runs.
///
/// Middleware also runs when the shell completes an option value. That is
/// not a command execution, so no event is sent then.
class AnalyticsMiddleware extends CommandMiddlewareHooks<GlobalOption, int> {
  final bool Function() analyticsEnabled;

  const AnalyticsMiddleware(this.analyticsEnabled);

  @override
  CommandContext<GlobalOption, int> onRun(
    final CommandContext<GlobalOption, int> context,
  ) {
    if (context.runMode == CommandRunMode.completion) return context;
    makeAnalyticsSender(analyticsEnabled, onAnalyticsEvent)(
      context.root().next?.command.name ?? context.command.name,
    );
    return context;
  }
}

///////////////
// Command span example (logic before and after a command runs)

/// Stopwatch for one command span, stored on the run's [ContextProvider].
class CommandSpan {
  final Stopwatch stopwatch = Stopwatch()..start();
}

/// Times a command from the moment it starts until it returns.
///
/// The stopwatch is stored on [CommandContext.provider] so the middleware
/// object itself holds no per-run state.
///
/// Does nothing when the shell completes an option value: no command runs
/// then, and anything printed would corrupt the completion response.
class CommandSpanMiddleware<O extends OptionDefinition, T>
    extends CommandMiddlewareHooks<O, T> {
  const CommandSpanMiddleware();

  @override
  CommandContext<O, T> onRun(final CommandContext<O, T> context) {
    if (context.runMode == CommandRunMode.completion) return context;
    context.provider.store(CommandSpan());
    print('>>> ${context.leaf().command.name} started');
    return context;
  }

  @override
  T? onReturn(final CommandContext<O, T> context, final T? response) {
    if (context.runMode == CommandRunMode.completion) return response;
    final stopwatch = context.provider.fetch<CommandSpan>().stopwatch..stop();
    print(
      '>>> ${context.leaf().command.name} returned $response '
      'after ${stopwatch.elapsed.inMilliseconds} ms',
    );
    return response;
  }
}
