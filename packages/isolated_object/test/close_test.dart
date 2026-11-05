// Ported from relic's isolated_object_close_test.dart. The pending-operation
// message assertion is relaxed to `contains('closed')` so it holds for the
// canonical (serverpod) teardown, which fails in-flight calls with
// "<runtimeType> is closed" rather than relic's "channel closed".
import 'dart:async';

import 'package:isolated_object/isolated_object.dart';
import 'package:test/test.dart';

void main() {
  test('Given an IsolatedObject, '
      'when close is called multiple times, '
      'then it handles it gracefully', () async {
    final isolated = IsolatedObject<_Counter>(() => _Counter(0));

    await isolated.close();
    await isolated.close(); // Second close should not throw.

    expect(isolated.isClosed, isTrue);
  });

  test('Given an IsolatedObject with pending operations, '
      'when it is closed, '
      'then pending operations fail with a closed error', () async {
    final isolated = IsolatedObject<_Counter>(() => _Counter(0));

    final pendingOperation = isolated.evaluate((counter) async {
      await Future<void>.delayed(const Duration(seconds: 10));
      return counter.value;
    });

    // Give the operation time to register as inflight.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await isolated.close();

    await expectLater(
      pendingOperation,
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('closed'),
        ),
      ),
    );
  });
}

class _Counter {
  int value;
  _Counter(this.value);
}
