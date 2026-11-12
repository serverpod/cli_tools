// New tests covering serverpod's superset semantics that relic's suite (built
// against the leaner copy) does not exercise: the isClosed guard, use-after-
// close, and the keepIsolateAlive flag.
import 'package:isolated_object/isolated_object.dart';
import 'package:test/test.dart';

void main() {
  test('Given an open IsolatedObject, '
      'then isClosed is false until close is called', () async {
    final isolated = IsolatedObject<_Counter>(() => _Counter(0));

    expect(isolated.isClosed, isFalse);
    await isolated.close();
    expect(isolated.isClosed, isTrue);
  });

  test('Given a closed IsolatedObject, '
      'when evaluate is called, '
      'then it throws a StateError', () async {
    final isolated = IsolatedObject<_Counter>(() => _Counter(0));
    await isolated.close();

    expect(
      () => isolated.evaluate((counter) => counter.value),
      throwsA(isA<StateError>()),
    );
  });

  test('Given keepIsolateAlive: false, '
      'when the object is used, '
      'then it still evaluates correctly', () async {
    final isolated = IsolatedObject<_Counter>(
      () => _Counter(7),
      keepIsolateAlive: false,
    );

    expect(await isolated.evaluate((counter) => counter.value), 7);

    await isolated.close();
  });
}

class _Counter {
  int value;
  _Counter(this.value);
}
