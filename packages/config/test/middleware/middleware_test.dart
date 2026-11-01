import 'package:config/src/middleware/middleware.dart';
import 'package:test/test.dart';

void main() {
  group('Given an empty MiddlewareChain', () {
    final chain = MiddlewareChain<String, String>();

    test(
      'when invoking the handler chain '
      'then the terminal handler receives the argument and its result is returned',
      () {
        final handler = chain.handlerChain((final arg) => 'terminal:$arg');

        expect(handler('input'), 'terminal:input');
      },
    );
  });

  group('Given a MiddlewareChain with one middleware', () {
    final chain = MiddlewareChain<String, String>([
      (final next) =>
          (final arg) => 'wrapped:${next('inner:$arg')}',
    ]);

    test(
      'when invoking the handler chain '
      'then the middleware runs around the terminal handler',
      () {
        final handler = chain.handlerChain((final arg) => 'terminal:$arg');

        expect(handler('input'), 'wrapped:terminal:inner:input');
      },
    );
  });

  group('Given a MiddlewareChain with two middlewares', () {
    late List<String> trace;
    late String result;

    setUp(() {
      trace = [];
      final chain = MiddlewareChain<String, String>([
        (final next) => (final arg) {
          trace.add('first-in:$arg');
          final value = next('from-first:$arg');
          trace.add('first-out:$value');
          return 'first:$value';
        },
        (final next) => (final arg) {
          trace.add('second-in:$arg');
          final value = next(arg);
          trace.add('second-out:$value');
          return 'second:$value';
        },
      ]);
      final handler = chain.handlerChain((final arg) {
        trace.add('terminal:$arg');
        return 'terminal:$arg';
      });
      result = handler('input');
    });

    test(
      'when invoking the handler chain '
      'then middlewares run first-to-last and unwind last-to-first',
      () {
        expect(trace, [
          'first-in:input',
          'second-in:from-first:input',
          'terminal:from-first:input',
          'second-out:terminal:from-first:input',
          'first-out:second:terminal:from-first:input',
        ]);
      },
    );

    test(
      'when invoking the handler chain '
      'then the result is the value returned by the first middleware',
      () {
        expect(result, 'first:second:terminal:from-first:input');
      },
    );
  });

  group('Given a middleware that does not call the next handler', () {
    test(
      'when invoking the handler chain '
      'then later middlewares and the terminal handler are skipped',
      () {
        final trace = <String>[];
        final chain = MiddlewareChain<String, String>([
          (final next) => (final arg) {
            trace.add('short-circuit:$arg');
            return 'stopped';
          },
          (final next) => (final arg) {
            trace.add('later:$arg');
            return next(arg);
          },
        ]);
        final handler = chain.handlerChain((final arg) {
          trace.add('terminal:$arg');
          return 'terminal:$arg';
        });

        expect(handler('input'), 'stopped');
        expect(trace, ['short-circuit:input']);
      },
    );
  });

  group('Given a MiddlewareChain with a growable middleware list', () {
    test(
      'when adding a middleware to a chain created with the default list '
      'then that middleware runs',
      () {
        final trace = <String>[];
        final chain = MiddlewareChain<String, String>();
        chain.addMiddleware(
          (final next) => (final arg) {
            trace.add(arg);
            return next(arg);
          },
        );

        chain.handlerChain((final arg) => arg)('input');

        expect(trace, ['input']);
      },
    );

    test(
      'when adding a middleware '
      'then it runs after the middlewares passed to the constructor',
      () {
        final trace = <String>[];
        final chain = MiddlewareChain<String, String>([
          (final next) => (final arg) {
            trace.add('initial:$arg');
            return next(arg);
          },
        ]);
        chain.addMiddleware(
          (final next) => (final arg) {
            trace.add('added:$arg');
            return next(arg);
          },
        );

        chain.handlerChain((final arg) {
          trace.add('terminal:$arg');
          return arg;
        })('input');

        expect(trace, ['initial:input', 'added:input', 'terminal:input']);
      },
    );

    test(
      'when a middleware is added after the handler is built '
      'then the existing handler does not run the new middleware',
      () {
        final trace = <String>[];
        final chain = MiddlewareChain<String, String>();
        final handler = chain.handlerChain((final arg) {
          trace.add('terminal:$arg');
          return arg;
        });
        chain.addMiddleware(
          (final next) => (final arg) {
            trace.add('late:$arg');
            return next(arg);
          },
        );

        handler('input');

        expect(trace, ['terminal:input']);
      },
    );
  });

  group('Given a composed handler', () {
    test(
      'when the handler is invoked twice '
      'then each invocation runs the full chain',
      () {
        var terminalCalls = 0;
        final chain = MiddlewareChain<int, int>([
          (final next) =>
              (final arg) => next(arg + 1),
        ]);
        final handler = chain.handlerChain((final arg) {
          terminalCalls++;
          return arg * 2;
        });

        expect([handler(1), handler(1)], [4, 4]);
        expect(terminalCalls, 2);
      },
    );

    test(
      'when the terminal handler throws '
      'then the exception propagates to the caller',
      () {
        final chain = MiddlewareChain<int, int>([
          (final next) =>
              (final arg) => next(arg),
        ]);
        final handler = chain.handlerChain((final arg) {
          throw StateError('boom');
        });

        expect(() => handler(1), throwsA(isA<StateError>()));
      },
    );
  });
}
