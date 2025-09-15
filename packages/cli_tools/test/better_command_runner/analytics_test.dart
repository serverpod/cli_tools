import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:cli_tools/better_command_runner.dart';
import 'package:test/test.dart';

import '../test_utils/test_utils.dart' show flushEventQueue;

class MockCommand extends Command {
  static String commandName = 'mock-command';

  @override
  String get description => 'Mock command used for testing';

  @override
  void run() {}

  @override
  String get name => commandName;

  MockCommand() {
    argParser.addOption(
      'name',
      defaultsTo: 'serverpod',
      allowed: <String>['serverpod'],
    );
  }
}

class CompletableMockCommand extends Command {
  static String commandName = 'completable-mock-command';

  @override
  String get description => 'Mock command used to test when process hangs';

  Completer<void> completer = Completer<void>();

  @override
  void run() async {
    await completer.future;
  }

  @override
  String get name => commandName;

  CompletableMockCommand() {
    argParser.addOption(
      'name',
      defaultsTo: 'serverpod',
      allowed: <String>['serverpod'],
    );
  }
}

void main() {
  late BetterCommandRunner runner;
  group('Given runner with null onAnalyticsEvent callback', () {
    final runner = BetterCommandRunner(
      'test',
      'this is a test cli',
      onAnalyticsEvent: null,
      messageOutput: const MessageOutput(),
    );

    test('when checking if analytics is enabled then false is returned.', () {
      expect(runner.analyticsEnabled(), isFalse);
    });

    test(
      'when checking available flags then analytics flag is not present.',
      () {
        expect(runner.argParser.options.keys, isNot(contains('analytics')));
      },
    );
  });

  group('Given runner with onAnalyticsEvent callback defined', () {
    final runner = BetterCommandRunner(
      'test',
      'this is a test cli',
      onAnalyticsEvent: (final event) {},
      messageOutput: const MessageOutput(),
    );

    test('when checking if analytics is enabled then true is returned.', () {
      expect(runner.analyticsEnabled(), isTrue);
    });

    test('when checking available flags then analytics is defined.', () {
      expect(runner.argParser.options.keys, contains('analytics'));
    });
  });

  group('Given runner with analytics enabled', () {
    List<String> events = [];
    setUp(() {
      runner = BetterCommandRunner(
        'test',
        'this is a test cli',
        onAnalyticsEvent: (final event) => events.add(event),
        messageOutput: const MessageOutput(),
      );
      assert(runner.analyticsEnabled());
    });

    tearDown(() {
      events = [];
    });

    test(
      'when running command with no-analytics flag then analytics is disabled.',
      () async {
        final args = ['--no-${BetterCommandRunnerFlags.analytics}'];
        await runner.run(args);

        await flushEventQueue();

        expect(runner.analyticsEnabled(), isFalse);
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
      'when running with no command then "help" analytics event is sent.',
      () async {
        await runner.run([]);

        await flushEventQueue();

        expect(events, hasLength(1));
        expect(events.first, equals('help'));
      },
    );

    test(
      'when running with only registered flag then "help" analytics event is sent.',
      () async {
        await runner.run(['--${BetterCommandRunnerFlags.analytics}']);

        await flushEventQueue();

        expect(events, hasLength(1));
        expect(events.first, equals('help'));
      },
    );

    test(
      'when running with help command then "help" analytics event is sent.',
      () async {
        await runner.run(['help']);

        await flushEventQueue();

        expect(events, hasLength(1));
        expect(events.first, equals('help'));
      },
    );

    test(
      'when running with help flag then "help" analytics event is sent.',
      () async {
        await runner.run(['--help']);

        await flushEventQueue();

        expect(events, hasLength(1));
        expect(events.first, equals('help'));
      },
    );
  });

  group('Given runner with registered command and analytics enabled', () {
    List<String> events = [];
    setUp(() {
      runner = BetterCommandRunner(
        'test',
        'this is a test cli',
        onAnalyticsEvent: (final event) => events.add(event),
        messageOutput: const MessageOutput(),
      )..addCommand(MockCommand());
      assert(runner.analyticsEnabled());
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
  });

  group('Given runner with registered command and analytics enabled', () {
    List<String> events = [];
    late CompletableMockCommand command;
    setUp(() {
      command = CompletableMockCommand();
      runner = BetterCommandRunner(
        'test',
        'this is a test cli',
        onAnalyticsEvent: (final event) => events.add(event),
        messageOutput: const MessageOutput(),
      )..addCommand(command);
      assert(runner.analyticsEnabled());
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
          'serverpod'
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
