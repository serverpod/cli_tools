import 'package:config/src/middleware/middleware_hooks.dart';
import 'package:test/test.dart';

void main() {
  group('Given default middleware hooks', () {
    const hooks = MiddlewareHooks<String, String?>();

    test(
      'when onRun is left unchanged '
      'then the next handler receives the original argument',
      () async {
        String? received;
        final handler = hooks.middleware((final arg) {
          received = arg;
          return 'ok';
        });

        await handler('original');

        expect(received, 'original');
      },
    );

    test(
      'when the next handler returns a value '
      'then that value is returned',
      () async {
        final handler = hooks.middleware((final arg) => 'from-next');

        expect(await handler('original'), 'from-next');
      },
    );

    test(
      'when the next handler throws '
      'then the exception propagates',
      () {
        final handler = hooks.middleware(
          (final arg) => throw StateError('boom'),
        );

        expect(handler('original'), throwsA(isA<StateError>()));
      },
    );
  });

  group('Given hooks whose onRun returns null', () {
    const hooks = _NullOnRun();

    test(
      'when the handler runs '
      'then the next handler receives null',
      () async {
        String? received;
        final handler = hooks.middleware((final arg) {
          received = arg;
          return 'ok';
        });

        await handler('original');

        expect(received, isNull);
      },
    );
  });

  group('Given a MiddlewareComposer with no onRun hook', () {
    const composer = MiddlewareComposer<String, String?>();

    test(
      'when the handler runs '
      'then the next handler receives the original argument',
      () async {
        String? received;
        final handler = composer.middleware((final arg) {
          received = arg;
          return 'ok';
        });

        await handler('original');

        expect(received, 'original');
      },
    );
  });

  group('Given a MiddlewareComposer whose onRun returns null', () {
    final composer = MiddlewareComposer<String, String?>(
      onRun: (final arg) => null,
    );

    test(
      'when the handler runs '
      'then the next handler receives null',
      () async {
        String? received;
        final handler = composer.middleware((final arg) {
          received = arg;
          return 'ok';
        });

        await handler('original');

        expect(received, isNull);
      },
    );
  });

  group(
    'Given a MiddlewareComposer whose onRun asynchronously returns null',
    () {
      final composer = MiddlewareComposer<String, String?>(
        onRun: (final arg) async => null,
      );

      test(
        'when the handler runs '
        'then the next handler receives null',
        () async {
          String? received;
          final handler = composer.middleware((final arg) {
            received = arg;
            return 'ok';
          });

          await handler('original');

          expect(received, isNull);
        },
      );
    },
  );

  group('Given hooks that replace the argument and the response', () {
    const hooks = _ReplacingHooks();

    test(
      'when the handler runs '
      'then the next handler receives the replacement argument',
      () async {
        String? received;
        final handler = hooks.middleware((final arg) {
          received = arg;
          return 'from-next';
        });

        await handler('original');

        expect(received, 'replaced-arg');
      },
    );

    test(
      'when the handler runs '
      'then the result is built from the replacement and the next response',
      () async {
        final handler = hooks.middleware((final arg) => 'from-next');

        expect(await handler('original'), 'replaced-arg/from-next');
      },
    );
  });

  group('Given hooks whose onReturn returns null', () {
    const hooks = _NullOnReturn();

    test(
      'when the handler runs '
      'then the result is null',
      () async {
        final handler = hooks.middleware((final arg) => 'from-next');

        expect(await handler('original'), isNull);
      },
    );
  });

  group('Given hooks that recover from a thrown error', () {
    late _RecoveringHooks hooks;
    late String result;

    group('when the next handler throws', () {
      setUp(() async {
        hooks = _RecoveringHooks();
        final handler = hooks.middleware(
          (final arg) => throw StateError('boom'),
        );
        result = await handler('original');
      });

      test('then the handler returns the onError value', () {
        expect(result, 'recovered:original');
      });

      test('then onReturn is not called', () {
        expect(hooks.onReturnCalled, isFalse);
      });
    });
  });

  group('Given hooks whose onRun throws', () {
    late bool nextCalled;
    late Object? error;

    group('when the handler runs', () {
      setUp(() async {
        nextCalled = false;
        final handler = const _ThrowingOnRun().middleware((final arg) {
          nextCalled = true;
          return 'ok';
        });
        try {
          await handler('original');
          error = null;
        } catch (thrown) {
          error = thrown;
        }
      });

      test('then the next handler is not called', () {
        expect(nextCalled, isFalse);
      });

      test('then the exception propagates', () {
        expect(error, isA<StateError>());
      });
    });
  });

  group('Given hooks whose onReturn throws', () {
    const hooks = _ThrowingOnReturn();

    test(
      'when the handler runs '
      'then the exception propagates',
      () {
        final handler = hooks.middleware((final arg) => 'from-next');

        expect(handler('original'), throwsA(isA<StateError>()));
      },
    );
  });

  group('Given a MiddlewareComposer with no onReturn hook', () {
    const composer = MiddlewareComposer<String, String>();

    test(
      'when the next handler returns a value '
      'then that value is returned',
      () async {
        final handler = composer.middleware((final arg) => 'from-next');

        expect(await handler('original'), 'from-next');
      },
    );
  });

  group('Given a MiddlewareComposer whose onReturn returns null', () {
    final composer = MiddlewareComposer<String?, String>(
      onReturn: (final arg, final response) => null,
    );

    test(
      'when the handler runs '
      'then the result is null',
      () async {
        final handler = composer.middleware((final arg) => 'from-next');

        expect(await handler('original'), isNull);
      },
    );
  });

  group('Given a MiddlewareComposer whose onReturn replaces the response', () {
    final composer = MiddlewareComposer<String, String>(
      onReturn: (final arg, final response) async => 'async:$response',
    );

    test(
      'when the handler runs '
      'then the result is the awaited hook value',
      () async {
        final handler = composer.middleware((final arg) => 'from-next');

        expect(await handler('original'), 'async:from-next');
      },
    );
  });

  group('Given a MiddlewareComposer with no onError hook', () {
    const composer = MiddlewareComposer<String, String>();

    test(
      'when the next handler throws '
      'then the exception propagates',
      () {
        final handler = composer.middleware(
          (final arg) => throw StateError('boom'),
        );

        expect(handler('original'), throwsA(isA<StateError>()));
      },
    );
  });

  group('Given a MiddlewareComposer whose onError recovers', () {
    final composer = MiddlewareComposer<String?, String>(
      onRun: (final arg) => 'replaced',
      onError: (final error, final stackTrace, final arg) => 'err:$arg',
    );

    test(
      'when the next handler throws '
      'then the result is the onError value for the replaced argument',
      () async {
        final handler = composer.middleware(
          (final arg) => throw StateError('boom'),
        );

        expect(await handler('original'), 'err:replaced');
      },
    );
  });

  group('Given a MiddlewareComposer whose onError returns null', () {
    final composer = MiddlewareComposer<String?, String>(
      onError: (final error, final stackTrace, final arg) async => null,
    );

    test(
      'when the next handler throws '
      'then the result is null',
      () async {
        final handler = composer.middleware(
          (final arg) => throw StateError('boom'),
        );

        expect(await handler('original'), isNull);
      },
    );
  });
}

class _NullOnRun extends MiddlewareHooks<String, String?> {
  const _NullOnRun();

  @override
  String? onRun(final String? arg) => null;
}

class _ReplacingHooks extends MiddlewareHooks<String, String> {
  const _ReplacingHooks();

  @override
  String onRun(final String arg) => 'replaced-arg';

  @override
  String onReturn(final String arg, final String response) => '$arg/$response';
}

class _NullOnReturn extends MiddlewareHooks<String?, String> {
  const _NullOnReturn();

  @override
  String? onReturn(final String arg, final String? response) => null;
}

class _RecoveringHooks extends MiddlewareHooks<String, String> {
  bool onReturnCalled = false;

  @override
  String onReturn(final String arg, final String response) {
    onReturnCalled = true;
    return response;
  }

  @override
  String onError(
    final Object error,
    final StackTrace stackTrace,
    final String arg,
  ) => 'recovered:$arg';
}

class _ThrowingOnRun extends MiddlewareHooks<String, String> {
  const _ThrowingOnRun();

  @override
  String onRun(final String arg) => throw StateError('onRun');
}

class _ThrowingOnReturn extends MiddlewareHooks<String, String> {
  const _ThrowingOnReturn();

  @override
  String onReturn(final String arg, final String response) =>
      throw StateError('onReturn');
}
