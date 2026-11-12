import 'dart:async';

import 'package:cli_tools/better_command_runner.dart';
import 'package:config/command.dart'
    show CompletionSettings, ContextProvider, OutputSinks;
import 'package:config/config.dart' show StringOption, Configuration;
import 'package:test/test.dart';

import '../test_utils/test_utils.dart' show flushEventQueue;

class MockCommand extends BetterCommand {
  static String commandName = 'mock-command';

  @override
  String get description => 'Mock command used for testing';

  @override
  FutureOr? runWithConfig(final Configuration commandConfig) {}

  @override
  String get name => commandName;

  MockCommand() {
    addOption(
      const StringOption(
        argName: 'name',
        defaultsTo: 'serverpod',
        allowedValues: ['serverpod'],
      ),
    );
  }
}

class CompletableMockCommand extends BetterCommand {
  static String commandName = 'completable-mock-command';

  @override
  String get description => 'Mock command used to test when process hangs';

  Completer<void> completer = Completer<void>();

  @override
  FutureOr? runWithConfig(final Configuration commandConfig) async {
    await completer.future;
  }

  @override
  String get name => commandName;

  CompletableMockCommand() {
    addOption(
      const StringOption(
        argName: 'name',
        defaultsTo: 'serverpod',
        allowedValues: ['serverpod'],
      ),
    );
  }
}

bool _hasAnalyticsOption(final BetterCommandRunner runner) {
  return runner.globalOptions.any(
    (final option) =>
        option.option.argName == BetterCommandRunnerFlags.analytics,
  );
}

void main() {
  late BetterCommandRunner runner;
  group('Given runner with null onAnalyticsEvent callback', () {
    late ContextProvider provider;

    setUp(() async {
      provider = ContextProvider();
      runner = BetterCommandRunner(
        'test',
        'this is a test cli',
        onAnalyticsEvent: null,
        messageOutput: const MessageOutput(),
      );
      await runner.run(const [], provider: provider);
      await flushEventQueue();
    });

    test('when checking if analytics is enabled then false is returned.', () {
      expect(provider.fetch<AnalyticsEnabled>().enabled, isFalse);
    });

    test(
      'when checking available flags then analytics flag is not present.',
      () {
        expect(_hasAnalyticsOption(runner), isFalse);
      },
    );
  });

  group('Given runner with onAnalyticsEvent callback defined', () {
    late ContextProvider provider;

    setUp(() async {
      provider = ContextProvider();
      runner = BetterCommandRunner(
        'test',
        'this is a test cli',
        onAnalyticsEvent: (final event, final properties) {},
        messageOutput: const MessageOutput(),
      );
      await runner.run(const [], provider: provider);
      await flushEventQueue();
    });

    test('when checking if analytics is enabled then true is returned.', () {
      expect(provider.fetch<AnalyticsEnabled>().enabled, isTrue);
    });

    test('when checking available flags then analytics is defined.', () {
      expect(_hasAnalyticsOption(runner), isTrue);
    });
  });

  group('Given runner with analytics enabled', () {
    List<String> events = [];
    setUp(() {
      runner = BetterCommandRunner(
        'test',
        'this is a test cli',
        onAnalyticsEvent: (final event, final _) => events.add(event),
        messageOutput: const MessageOutput(),
      );
    });

    tearDown(() {
      events = [];
    });

    test(
      'when running command with no-analytics flag then analytics is disabled.',
      () async {
        final provider = ContextProvider();
        final args = ['--no-${BetterCommandRunnerFlags.analytics}'];
        await runner.run(args, provider: provider);

        await flushEventQueue();

        expect(provider.fetch<AnalyticsEnabled>().enabled, isFalse);
      },
    );

    test(
      'when running invalid command then "invalid" analytics event is sent.',
      () async {
        final args = ['this could be a command argument'];

        try {
          await runner.run(args);
        } catch (_) {
          // Ignore any exception
        }

        await flushEventQueue();

        expect(events, hasLength(1));
        expect(events.first, equals('invalid'));
      },
    );

    test(
      'when running with unknown command then "invalid" analytics event is sent.',
      () async {
        final args = ['--unknown-command'];

        try {
          await runner.run(args);
        } catch (_) {
          // Ignore any exception
        }

        await flushEventQueue();

        expect(events, hasLength(1));
        expect(events.first, equals('invalid'));
      },
    );

    test(
      'when running with no command then the runner name is sent.',
      () async {
        await runner.run([]);

        await flushEventQueue();

        expect(events, hasLength(1));
        expect(events.first, equals(runner.name));
      },
    );

    test(
      'when running with only a registered flag then the runner name is sent.',
      () async {
        await runner.run(['--${BetterCommandRunnerFlags.analytics}']);

        await flushEventQueue();

        expect(events, hasLength(1));
        expect(events.first, equals(runner.name));
      },
    );

    test(
      'when running with help command then "help" analytics event is sent.',
      () async {
        runner.addCommand(MockCommand());
        await runner.run(['help']);

        await flushEventQueue();

        expect(events, hasLength(1));
        expect(events.first, equals('help'));
      },
      skip: 'Currently not reporting analytics for help invocations',
    );

    test(
      'when running with help flag then "help" analytics event is sent.',
      () async {
        await runner.run(['--help']);

        await flushEventQueue();

        expect(events, hasLength(1));
        expect(events.first, equals('help'));
      },
      skip: 'Currently not reporting analytics for help invocations',
    );
  });

  group('Given runner with registered command and analytics enabled', () {
    List<String> events = [];
    setUp(() {
      runner = BetterCommandRunner(
        'test',
        'this is a test cli',
        onAnalyticsEvent: (final event, final _) => events.add(event),
        messageOutput: const MessageOutput(),
      )..addCommand(MockCommand());
    });

    tearDown(() {
      events = [];
    });

    test(
      'when running with registered command then command name is sent,',
      () async {
        final args = [MockCommand.commandName];

        await runner.run(args);

        await flushEventQueue();

        expect(events, hasLength(1));
        expect(events.first, equals(MockCommand.commandName));
      },
    );

    test(
      'when running with registered command and option then command name is sent,',
      () async {
        final args = [MockCommand.commandName, '--name', 'serverpod'];

        await runner.run(args);

        await flushEventQueue();

        expect(events, hasLength(1));
        expect(events.first, equals(MockCommand.commandName));
      },
    );

    test(
      'when running with registered command but invalid option then "invalid" analytics event is sent,',
      () async {
        final args = [MockCommand.commandName, '--name', 'invalid'];

        try {
          await runner.run(args);
        } catch (_) {
          // Ignore any exception
        }

        await flushEventQueue();

        expect(events, hasLength(1));
        expect(events.first, equals('invalid'));
      },
    );

    test(
      'when running in completion mode then no analytics event is sent.',
      () async {
        final completionOutput = StringBuffer();
        runner = BetterCommandRunner(
          'test',
          'this is a test cli',
          onAnalyticsEvent: (final event, final _) => events.add(event),
          messageOutput: const MessageOutput(),
          completion: CompletionSettings(
            exitAfterResponse: false,
            sinks: OutputSinks(out: completionOutput),
          ),
        )..addCommand(MockCommand());

        await runner.run([
          '__complete',
          MockCommand.commandName,
          '--name',
          '',
        ]);

        await flushEventQueue();

        expect(events, isEmpty);
      },
    );
  });

  group('Given runner with registered command and analytics enabled', () {
    List<String> events = [];
    late CompletableMockCommand command;
    setUp(() {
      command = CompletableMockCommand();
      runner = BetterCommandRunner(
        'test',
        'this is a test cli',
        onAnalyticsEvent: (final event, final _) => events.add(event),
        messageOutput: const MessageOutput(),
      )..addCommand(command);
    });

    tearDown(() {
      events = [];
    });

    test(
      'when running with registered command that hangs then command name is sent',
      () async {
        final args = [CompletableMockCommand.commandName];

        unawaited(runner.run(args));

        await flushEventQueue();

        expect(events, hasLength(1));
        expect(events.first, equals(CompletableMockCommand.commandName));

        command.completer.complete();
      },
    );

    test(
      'when running with registered command that hangs and option then command name is sent,',
      () async {
        final args = [
          CompletableMockCommand.commandName,
          '--name',
          'serverpod',
        ];

        unawaited(runner.run(args));

        await flushEventQueue();

        expect(events, hasLength(1));
        expect(events.first, equals(CompletableMockCommand.commandName));

        command.completer.complete();
      },
    );

    test(
      'when running with registered command that hangs but invalid option then "invalid" analytics event is sent,',
      () async {
        final args = [CompletableMockCommand.commandName, '--name', 'invalid'];

        unawaited(
          runner.run(args).catchError((final _) {
            // Ignore parse error
          }),
        );

        await flushEventQueue();

        expect(events, hasLength(1));
        expect(events.first, equals('invalid'));

        command.completer.complete();
      },
    );
  });
}
