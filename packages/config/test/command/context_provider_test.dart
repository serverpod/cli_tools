import 'package:config/command.dart';
import 'package:config/config.dart';
import 'package:test/test.dart';

import 'command_fixtures.dart';

void main() {
  group('Given a context provider and middleware on a command', () {
    late ContextProvider provider;
    late UserSession? sessionSeenByCommand;
    late CommandReport? reportSeenByMiddleware;

    setUp(() async {
      provider = ContextProvider();
      sessionSeenByCommand = null;
      reportSeenByMiddleware = null;
      final command = CommandImpl.leafWithRunFunction<OptionDefinition, String>(
        name: 'build',
        description: 'Build the app',
        middlewares: [
          (final next) => (final context) {
            context.provider.store(const UserSession('ada'));
            final result = next(context);
            reportSeenByMiddleware = context.provider.fetch<CommandReport>();
            return result;
          },
        ],
        run: (final context) {
          sessionSeenByCommand = context.provider.fetch<UserSession>();
          context.provider.store(const CommandReport('built'));
          return 'build';
        },
      );
      final runner = CommandRunner(
        'tool',
        'Tools',
        subcommands: [command],
      );
      await runner.run(['build'], provider: provider);
    });

    test(
      'when the middleware stores a session before the command '
      'then the command retrieves that session',
      () {
        expect(sessionSeenByCommand?.name, 'ada');
      },
    );

    test(
      'when the command stores a report '
      'then the middleware retrieves that report after the command returns',
      () {
        expect(reportSeenByMiddleware?.summary, 'built');
      },
    );

    test(
      'when the command line finishes '
      'then the caller retrieves the report stored by the command',
      () {
        expect(provider.fetch<CommandReport>().summary, 'built');
      },
    );
  });

  group(
    'Given a context provider shared by nested commands and middleware',
    () {
      late ContextProvider provider;
      late UserSession? sessionSeenByBranch;
      late UserSession? sessionSeenByLeaf;
      late CommandReport? reportSeenByBranch;

      setUp(() async {
        provider = ContextProvider();
        sessionSeenByBranch = null;
        sessionSeenByLeaf = null;
        reportSeenByBranch = null;
        final check = CommandImpl.leafWithRunFunction<OptionDefinition, String>(
          name: 'check',
          description: 'Check the app',
          run: (final context) {
            sessionSeenByLeaf = context.provider.fetch<UserSession>();
            context.provider.store(const CommandReport('checked'));
            return 'check';
          },
        );
        final build = CommandImpl.branch<OptionDefinition, String>(
          name: 'build',
          description: 'Build the app',
          subcommands: [check],
          middlewares: [
            (final next) => (final context) {
              sessionSeenByBranch = context.provider.fetch<UserSession>();
              final result = next(context);
              reportSeenByBranch = context.provider.fetch<CommandReport>();
              return result;
            },
          ],
        );
        final runner = CommandRunner<OptionDefinition, String>(
          'tool',
          'Tools',
          middlewares: [
            (final next) => (final context) {
              context.provider.store(const UserSession('ada'));
              return next(context);
            },
          ],
          subcommands: [build],
        );
        await runner.run(['build', 'check'], provider: provider);
      });

      test(
        'when runner middleware stores a session '
        'then a branch command middleware retrieves that session',
        () {
          expect(sessionSeenByBranch?.name, 'ada');
        },
      );

      test(
        'when runner middleware stores a session '
        'then the leaf command retrieves that session',
        () {
          expect(sessionSeenByLeaf?.name, 'ada');
        },
      );

      test(
        'when the leaf command stores a report '
        'then the branch middleware retrieves that report',
        () {
          expect(reportSeenByBranch?.summary, 'checked');
        },
      );

      test(
        'when the command line finishes '
        'then the caller retrieves the report stored by the leaf command',
        () {
          expect(provider.fetch<CommandReport>().summary, 'checked');
        },
      );
    },
  );

  group(
    'Given a standalone command and a context provider that already holds a session',
    () {
      late ContextProvider provider;
      late UserSession? sessionSeenByCommand;
      late CommandReport? reportSeenByCommand;

      setUp(() async {
        provider = ContextProvider()..store(const UserSession('ada'));
        sessionSeenByCommand = null;
        reportSeenByCommand = null;
        final trace = <String>[];
        final version = RecordingCommand<OptionDefinition>(
          name: 'version',
          description: 'Show the version',
          trace: trace,
          standalone: true,
          middlewares: [
            (final next) => (final context) {
              context.provider.store(const CommandReport('versioned'));
              return next(context);
            },
          ],
          body: (final context) {
            sessionSeenByCommand = context.provider.fetch<UserSession>();
            reportSeenByCommand = context.provider.fetch<CommandReport>();
            return 'version';
          },
        );
        final build = RecordingCommand<OptionDefinition>(
          name: 'build',
          description: 'Build the app',
          trace: trace,
          middlewares: [
            (final next) => (final context) {
              context.provider.store(const UserSession('replaced'));
              return next(context);
            },
          ],
          subcommands: [version],
        );
        final runner = CommandRunner(
          'tool',
          'Tools',
          subcommands: [build],
        );
        await runner.run(['build', 'version'], provider: provider);
      });

      test(
        'when the standalone command runs '
        'then it retrieves the session stored before the run',
        () {
          expect(sessionSeenByCommand?.name, 'ada');
        },
      );

      test(
        'when its middleware stores a report '
        'then the standalone command retrieves that report',
        () {
          expect(reportSeenByCommand?.summary, 'versioned');
        },
      );

      test(
        'when the command line finishes '
        'then the caller retrieves the report stored by its middleware',
        () {
          expect(provider.fetch<CommandReport>().summary, 'versioned');
        },
      );
    },
  );

  group('Given no context provider', () {
    late ContextProvider? seen;

    setUp(() async {
      final command = CommandImpl.leafWithRunFunction<OptionDefinition, void>(
        name: 'build',
        description: 'Build the app',
        run: (final context) {
          seen = context.provider;
        },
      );
      final runner = CommandRunner(
        'tool',
        'Tools',
        subcommands: [command],
      );
      await runner.run(['build']);
    });

    test('when a command runs then its run context has a default provider', () {
      expect(seen, isNotNull);
    });
  });

  group('Given a context provider that holds a session and a report', () {
    late ContextProvider provider;

    setUp(() async {
      provider = ContextProvider()
        ..store(const UserSession('ada'))
        ..store(const CommandReport('built'));
      final command = CommandImpl.leafWithRunFunction<OptionDefinition, void>(
        name: 'logout',
        description: 'Log out',
        run: (final context) {
          context.provider.remove<UserSession>();
        },
      );
      final runner = CommandRunner(
        'tool',
        'Tools',
        subcommands: [command],
      );
      await runner.run(['logout'], provider: provider);
    });

    test(
      'when a command removes the session '
      'then the caller still retrieves the report',
      () {
        expect(provider.fetch<CommandReport>().summary, 'built');
      },
    );

    test(
      'when a command removes the session '
      'then the caller cannot retrieve that session',
      () {
        expect(
          () => provider.fetch<UserSession>(),
          throwsA(
            isA<ContextValueNotFound>().having(
              (final error) => error.type,
              'type',
              UserSession,
            ),
          ),
        );
      },
    );
  });

  group('Given an empty context provider', () {
    late ContextProvider provider;

    setUp(() {
      provider = ContextProvider();
    });

    test(
      'when a missing session is fetched '
      'then the error names that type',
      () {
        expect(
          () => provider.fetch<UserSession>(),
          throwsA(
            isA<ContextValueNotFound>().having(
              (final error) => error.type,
              'type',
              UserSession,
            ),
          ),
        );
      },
    );

    test(
      'when a missing session is maybe-fetched '
      'then null is returned',
      () {
        expect(provider.maybeFetch<UserSession>(), isNull);
      },
    );

    test('when a missing session is checked then has is false', () {
      expect(provider.has<UserSession>(), isFalse);
    });

    test('when a missing session is removed then the provider stays empty', () {
      provider.remove<UserSession>();
      expect(provider.has<UserSession>(), isFalse);
    });
  });

  group('Given a context provider', () {
    late ContextProvider provider;

    setUp(() {
      provider = ContextProvider();
    });

    test('when a session is stored then fetch returns that session', () {
      provider.store(const UserSession('ada'));
      expect(provider.fetch<UserSession>().name, 'ada');
    });

    test(
      'when a session is stored then maybeFetch returns that session',
      () {
        provider.store(const UserSession('ada'));
        expect(provider.maybeFetch<UserSession>()?.name, 'ada');
      },
    );

    test('when a session is stored then has is true', () {
      provider.store(const UserSession('ada'));
      expect(provider.has<UserSession>(), isTrue);
    });

    test(
      'when a session is stored again '
      'then fetch returns the new session',
      () {
        provider
          ..store(const UserSession('ada'))
          ..store(const UserSession('grace'));
        expect(provider.fetch<UserSession>().name, 'grace');
      },
    );

    test(
      'when a session and a report are stored '
      'then fetch returns the session',
      () {
        provider
          ..store(const UserSession('ada'))
          ..store(const CommandReport('built'));
        expect(provider.fetch<UserSession>().name, 'ada');
      },
    );

    test(
      'when a session and a report are stored '
      'then fetch returns the report',
      () {
        provider
          ..store(const UserSession('ada'))
          ..store(const CommandReport('built'));
        expect(provider.fetch<CommandReport>().summary, 'built');
      },
    );

    test(
      'when a session is removed '
      'then that session is gone',
      () {
        provider
          ..store(const UserSession('ada'))
          ..remove<UserSession>();
        expect(provider.maybeFetch<UserSession>(), isNull);
      },
    );

    test(
      'when a session is removed '
      'then the report stored beside it remains',
      () {
        provider
          ..store(const UserSession('ada'))
          ..store(const CommandReport('built'))
          ..remove<UserSession>();
        expect(provider.fetch<CommandReport>().summary, 'built');
      },
    );
  });

  group('Given a session stored under Object', () {
    late Object session;
    late ContextProvider provider;

    setUp(() {
      session = const UserSession('ada');
      provider = ContextProvider()..store(session);
    });

    test('when Object is fetched then that session is returned', () {
      expect(provider.fetch<Object>(), same(session));
    });

    test('when UserSession is maybe-fetched then null is returned', () {
      expect(provider.maybeFetch<UserSession>(), isNull);
    });

    test('when UserSession is checked then has is false', () {
      expect(provider.has<UserSession>(), isFalse);
    });
  });

  group('Given a context provider seeded from a type map', () {
    test(
      'when the map keys a session under UserSession '
      'then fetch returns that session',
      () {
        const session = UserSession('ada');
        final provider = ContextProvider(<Type, Object>{UserSession: session});
        expect(provider.fetch<UserSession>(), same(session));
      },
    );

    test(
      'when the map keys a session under Object '
      'then fetch Object returns that session',
      () {
        const session = UserSession('ada');
        final provider = ContextProvider(<Type, Object>{Object: session});
        expect(provider.fetch<Object>(), same(session));
      },
    );

    test(
      'when the map keys a session under Object '
      'then the UserSession slot is empty',
      () {
        final provider = ContextProvider(<Type, Object>{
          Object: const UserSession('ada'),
        });
        expect(provider.has<UserSession>(), isFalse);
      },
    );

    test(
      'when the caller changes the map '
      'then the provider still returns the original session',
      () {
        const session = UserSession('ada');
        final values = <Type, Object>{UserSession: session};
        final provider = ContextProvider(values);
        values[UserSession] = const UserSession('grace');
        expect(provider.fetch<UserSession>().name, 'ada');
      },
    );
  });

  group(
    'Given a context provider whose map stores a string under UserSession',
    () {
      late ContextProvider provider;

      setUp(() {
        provider = ContextProvider(<Type, Object>{UserSession: 'ada'});
      });

      test(
        'when the session is fetched '
        'then it throws ContextValueNotFound',
        () {
          expect(
            () => provider.fetch<UserSession>(),
            throwsA(isA<ContextValueNotFound>()),
          );
        },
      );

      test('when the session is maybe-fetched then null is returned', () {
        expect(provider.maybeFetch<UserSession>(), isNull);
      });

      test('when the session is checked then has is false', () {
        expect(provider.has<UserSession>(), isFalse);
      });
    },
  );
}

class UserSession {
  const UserSession(this.name);

  final String name;
}

class CommandReport {
  const CommandReport(this.summary);

  final String summary;
}
