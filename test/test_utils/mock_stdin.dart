import 'dart:async';
import 'dart:convert';
import 'dart:io';

class MockStdin implements Stdin {
  final List<String> _inputs;
  int _currentIndex = 0;

  MockStdin(this._inputs);

  @override
  bool get echoMode => throw UnimplementedError();

  @override
  set echoMode(bool value) => throw UnimplementedError();

  @override
  bool get lineMode => throw UnimplementedError();

  @override
  Future<bool> any(bool Function(List<int> element) test) {
    throw UnimplementedError();
  }

  @override
  Stream<List<int>> asBroadcastStream(
      {void Function(StreamSubscription<List<int>> subscription)? onListen,
      void Function(StreamSubscription<List<int>> subscription)? onCancel}) {
    throw UnimplementedError();
  }

  @override
  Stream<E> asyncExpand<E>(Stream<E>? Function(List<int> event) convert) {
    throw UnimplementedError();
  }

  @override
  Stream<E> asyncMap<E>(FutureOr<E> Function(List<int> event) convert) {
    throw UnimplementedError();
  }

  @override
  Stream<R> cast<R>() {
    throw UnimplementedError();
  }

  @override
  Future<bool> contains(Object? needle) {
    throw UnimplementedError();
  }

  @override
  Stream<List<int>> distinct(
      [bool Function(List<int> previous, List<int> next)? equals]) {
    throw UnimplementedError();
  }

  @override
  Future<E> drain<E>([E? futureValue]) {
    throw UnimplementedError();
  }

  @override
  Future<List<int>> elementAt(int index) {
    throw UnimplementedError();
  }

  @override
  Future<bool> every(bool Function(List<int> element) test) {
    throw UnimplementedError();
  }

  @override
  Stream<S> expand<S>(Iterable<S> Function(List<int> element) convert) {
    throw UnimplementedError();
  }

  @override
  Future<List<int>> get first => throw UnimplementedError();

  @override
  Future<List<int>> firstWhere(bool Function(List<int> element) test,
      {List<int> Function()? orElse}) {
    throw UnimplementedError();
  }

  @override
  Future<S> fold<S>(
      S initialValue, S Function(S previous, List<int> element) combine) {
    throw UnimplementedError();
  }

  @override
  Future<void> forEach(void Function(List<int> element) action) {
    throw UnimplementedError();
  }

  @override
  Stream<List<int>> handleError(Function onError,
      {bool Function(dynamic error)? test}) {
    throw UnimplementedError();
  }

  @override
  bool get hasTerminal => throw UnimplementedError();

  @override
  bool get isBroadcast => throw UnimplementedError();

  @override
  Future<bool> get isEmpty => throw UnimplementedError();

  @override
  Future<String> join([String separator = '']) {
    throw UnimplementedError();
  }

  @override
  Future<List<int>> get last => throw UnimplementedError();

  @override
  Future<List<int>> lastWhere(bool Function(List<int> element) test,
      {List<int> Function()? orElse}) {
    throw UnimplementedError();
  }

  @override
  Future<int> get length => throw UnimplementedError();

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    throw UnimplementedError();
  }

  @override
  Stream<S> map<S>(S Function(List<int> event) convert) {
    throw UnimplementedError();
  }

  @override
  Future pipe(StreamConsumer<List<int>> streamConsumer) {
    throw UnimplementedError();
  }

  @override
  int readByteSync() {
    throw UnimplementedError();
  }

  @override
  String? readLineSync(
      {Encoding encoding = systemEncoding, bool retainNewlines = false}) {
    if (_currentIndex < _inputs.length) {
      return _inputs[_currentIndex++];
    }
    return null; // Simulate end of input
  }

  @override
  Future<List<int>> reduce(
      List<int> Function(List<int> previous, List<int> element) combine) {
    throw UnimplementedError();
  }

  @override
  Future<List<int>> get single => throw UnimplementedError();

  @override
  Future<List<int>> singleWhere(bool Function(List<int> element) test,
      {List<int> Function()? orElse}) {
    throw UnimplementedError();
  }

  @override
  Stream<List<int>> skip(int count) {
    throw UnimplementedError();
  }

  @override
  Stream<List<int>> skipWhile(bool Function(List<int> element) test) {
    throw UnimplementedError();
  }

  @override
  bool get supportsAnsiEscapes => throw UnimplementedError();

  @override
  Stream<List<int>> take(int count) {
    throw UnimplementedError();
  }

  @override
  Stream<List<int>> takeWhile(bool Function(List<int> element) test) {
    throw UnimplementedError();
  }

  @override
  Stream<List<int>> timeout(Duration timeLimit,
      {void Function(EventSink<List<int>> sink)? onTimeout}) {
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
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) {
    throw UnimplementedError();
  }

  @override
  Stream<List<int>> where(bool Function(List<int> event) test) {
    throw UnimplementedError();
  }

  @override
  set lineMode(bool lineMode) {}

  @override
  bool echoNewlineMode = false;
}
