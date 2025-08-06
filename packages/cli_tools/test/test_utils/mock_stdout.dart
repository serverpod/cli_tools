import 'dart:convert';
import 'dart:io';

class MockStdout implements Stdout {
  final _buffer = StringBuffer();

  @override
  Encoding encoding = utf8;

  @override
  // ignore required for Dart 3.3
  // ignore: override_on_non_overriding_member
  String lineTerminator = '\n';

  String get output => _buffer.toString();

  @override
  void add(List<int> data) {
    _buffer.write(utf8.decode(data));
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    throw UnimplementedError();
  }

  @override
  Future addStream(Stream<List<int>> stream) {
    throw UnimplementedError();
  }

  @override
  Future close() {
    return Future.value();
  }

  @override
  Future get done => Future.value();

  @override
  Future flush() {
    return Future.value();
  }

  @override
  bool get hasTerminal => true;

  @override
  IOSink get nonBlocking => throw UnimplementedError();

  @override
  bool get supportsAnsiEscapes => false;

  @override
  int get terminalColumns => 80;

  @override
  int get terminalLines => 24;

  @override
  void write(Object? object) {
    if (object.toString() == '\x1B[2J\x1B[H') {
      _buffer.clear();
    } else {
      _buffer.write(object);
    }
  }

  @override
  void writeAll(Iterable objects, [String sep = '']) {
    _buffer.writeAll(objects, sep);
  }

  @override
  void writeCharCode(int charCode) {
    _buffer.writeCharCode(charCode);
  }

  @override
  void writeln([Object? object = '']) {
    _buffer.writeln(object);
  }
}
