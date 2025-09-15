import 'dart:async';
import 'dart:convert';
import 'dart:io';

class MockStdin implements Stdin {
  final List<String> _textInputs;
  final List<int> _keyInputs;
  int _currentTextIndex = 0;
  int _currentByteIndex = 0;

  MockStdin({
    final List<String> textInputs = const [],
    final List<int> keyInputs = const [],
  })  : _textInputs = textInputs,
        _keyInputs = keyInputs;

  @override
  bool get echoMode => false;

  @override
  set echoMode(final bool value) {}

  @override
  bool get lineMode => false;

  @override
  Future<bool> any(final bool Function(List<int> element) test) {
    throw UnimplementedError();
  }

  @override
  Stream<List<int>> asBroadcastStream({
    final void Function(StreamSubscription<List<int>> subscription)? onListen,
    final void Function(StreamSubscription<List<int>> subscription)? onCancel,
  }) {
    throw UnimplementedError();
  }

  @override
  Stream<E> asyncExpand<E>(final Stream<E>? Function(List<int> event) convert) {
    throw UnimplementedError();
  }

  @override
  Stream<E> asyncMap<E>(final FutureOr<E> Function(List<int> event) convert) {
    throw UnimplementedError();
  }

  @override
  Stream<R> cast<R>() {
    throw UnimplementedError();
  }

  @override
  Future<bool> contains(final Object? needle) {
    throw UnimplementedError();
  }

  @override
  Stream<List<int>> distinct([
    final bool Function(List<int> previous, List<int> next)? equals,
  ]) {
    throw UnimplementedError();
  }

  @override
  Future<E> drain<E>([final E? futureValue]) {
    throw UnimplementedError();
  }

  @override
  Future<List<int>> elementAt(final int index) {
    throw UnimplementedError();
  }

  @override
  Future<bool> every(final bool Function(List<int> element) test) {
    throw UnimplementedError();
  }

  @override
  Stream<S> expand<S>(final Iterable<S> Function(List<int> element) convert) {
    throw UnimplementedError();
  }

  @override
  Future<List<int>> get first => throw UnimplementedError();

  @override
  Future<List<int>> firstWhere(
    final bool Function(List<int> element) test, {
    final List<int> Function()? orElse,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<S> fold<S>(
    final S initialValue,
    final S Function(S previous, List<int> element) combine,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> forEach(final void Function(List<int> element) action) {
    throw UnimplementedError();
  }

  @override
  Stream<List<int>> handleError(
    final Function onError, {
    final bool Function(dynamic error)? test,
  }) {
    throw UnimplementedError();
  }

  @override
  bool get hasTerminal => throw UnimplementedError();

  @override
  bool get isBroadcast => throw UnimplementedError();

  @override
  Future<bool> get isEmpty => throw UnimplementedError();

  @override
  Future<String> join([final String separator = '']) {
    throw UnimplementedError();
  }

  @override
  Future<List<int>> get last => throw UnimplementedError();

  @override
  Future<List<int>> lastWhere(
    final bool Function(List<int> element) test, {
    final List<int> Function()? orElse,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<int> get length => throw UnimplementedError();

  @override
  StreamSubscription<List<int>> listen(
    final void Function(List<int> event)? onData, {
    final Function? onError,
    final void Function()? onDone,
    final bool? cancelOnError,
  }) {
    throw UnimplementedError();
  }

  @override
  Stream<S> map<S>(final S Function(List<int> event) convert) {
    throw UnimplementedError();
  }

  @override
  Future pipe(final StreamConsumer<List<int>> streamConsumer) {
    throw UnimplementedError();
  }

  @override
  int readByteSync() {
    if (_currentByteIndex < _keyInputs.length) {
      return _keyInputs[_currentByteIndex++];
    }
    return -1; // Simulate end of input
  }

  @override
  String? readLineSync({
    final Encoding encoding = systemEncoding,
    final bool retainNewlines = false,
  }) {
    if (_currentTextIndex < _textInputs.length) {
      return _textInputs[_currentTextIndex++];
    }
    return null; // Simulate end of input
  }

  @override
  Future<List<int>> reduce(
    final List<int> Function(List<int> previous, List<int> element) combine,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<List<int>> get single => throw UnimplementedError();

  @override
  Future<List<int>> singleWhere(
    final bool Function(List<int> element) test, {
    final List<int> Function()? orElse,
  }) {
    throw UnimplementedError();
  }

  @override
  Stream<List<int>> skip(final int count) {
    throw UnimplementedError();
  }

  @override
  Stream<List<int>> skipWhile(final bool Function(List<int> element) test) {
    throw UnimplementedError();
  }

  @override
  bool get supportsAnsiEscapes => throw UnimplementedError();

  @override
  Stream<List<int>> take(final int count) {
    throw UnimplementedError();
  }

  @override
  Stream<List<int>> takeWhile(final bool Function(List<int> element) test) {
    throw UnimplementedError();
  }

  @override
  Stream<List<int>> timeout(
    final Duration timeLimit, {
    final void Function(EventSink<List<int>> sink)? onTimeout,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<List<int>>> toList() {
    throw UnimplementedError();
  }

  @override
  Future<Set<List<int>>> toSet() {
    throw UnimplementedError();
  }

  @override
  Stream<S> transform<S>(
      final StreamTransformer<List<int>, S> streamTransformer) {
    throw UnimplementedError();
  }

  @override
  Stream<List<int>> where(final bool Function(List<int> event) test) {
    throw UnimplementedError();
  }

  @override
  set lineMode(final bool lineMode) {}

  @override
  bool echoNewlineMode = false;
}
